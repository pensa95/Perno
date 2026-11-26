import SwiftUI
import SwiftData
import PernoCore

/// Storico (tavola «L Sessioni»): selettore dell'anno, Sessioni / Esercizi, una lista sola con il mese
/// come intestazione fissa, la settimana come separatore con il conteggio e il giorno a sinistra
/// con più sessioni impilate. Riga = durata e set, coppa se c'è un record; niente volume.
/// Il tocco su una riga apre il Dettaglio sessione. Esercizi (tavola «L Esercizi»): ricerca, gruppi
/// per scheda, record personale a destra, ultima volta, «nuovo» e stallo.
struct StoricoView: View {
    enum Vista: Hashable {
        case sessioni
        case esercizi
    }

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessioni: [WorkoutSession]
    @Query(sort: \Routine.createdAt) private var schede: [Routine]
    @State private var ricerca = ""
    /// Letta solo per ridisegnare i pesi quando cambia l'unità.
    @AppStorage(Impostazioni.unita) private var unita: WeightUnit = .kilograms
    @State private var vista: Vista = .sessioni
    /// Anno scelto; `nil` = il più recente con sessioni.
    @State private var annoScelto: Int?

    private var calendario: Calendar { .current }

    // MARK: Dati

    /// Sessioni nello storico: chiuse, escluse quelle chiuse da sole e non ancora salvate.
    private var chiuse: [WorkoutSession] {
        sessioni.filter(\.nelloStorico)
    }

    /// Righe delle sessioni. La coppa viene dai record di ogni esercizio, calcolati in un solo
    /// passaggio (`ExerciseDetail.recordDates`), non sessione per sessione.
    private func vociStorico(_ chiuse: [WorkoutSession], esercizi: [ExerciseHistory.Exercise<UUID>]) -> [SessionHistory.Item<UUID>] {
        let conRecord = esercizi.reduce(into: Set<Date>()) { $0.formUnion(ExerciseDetail.recordDates($1)) }
        return chiuse.map { sessione in
            SessionHistory.Item(
                id: sessione.id,
                start: sessione.startedAt,
                title: sessione.titolo,
                duration: sessione.durata,
                sets: sessione.setFatti,
                isFree: sessione.isFree,
                exercises: sessione.exercises.filter { $0.sets.contains(where: \.isDone) }.count,
                hasRecord: conRecord.contains(sessione.startedAt))
        }
    }

    /// Esercizi fatti nelle sessioni dello storico, con i set di lavoro di ogni volta.
    private func eserciziStorico(_ chiuse: [WorkoutSession]) -> [ExerciseHistory.Exercise<UUID>] {
        var volte: [UUID: (nome: String, voci: [ExerciseHistory.Entry])] = [:]
        // A tempo o a ripetizioni come l'ultima volta (UI v5), calcolato una volta per esercizio.
        var aTempo: [UUID: Bool] = [:]
        for sessione in chiuse {
            for voce in sessione.exercises {
                guard let esercizio = voce.exercise else { continue }
                let modo = aTempo[esercizio.id] ?? esercizio.ultimaVoltaATempo
                aTempo[esercizio.id] = modo
                guard voce.isTimed == modo else { continue }
                let alzate = WorkoutSession.alzate(voce)
                guard !alzate.isEmpty else { continue }
                volte[esercizio.id, default: (esercizio.name, [])].voci
                    .append(ExerciseHistory.Entry(date: sessione.startedAt, lifts: alzate))
            }
        }
        return volte.map {
            ExerciseHistory.Exercise(id: $0.key, name: $0.value.nome, entries: $0.value.voci,
                                     timed: aTempo[$0.key] ?? false)
        }
    }

    private func gruppiEsercizi(_ esercizi: [ExerciseHistory.Exercise<UUID>]) -> [ExerciseHistory.Group<UUID>] {
        ExerciseHistory.groups(
            exercises: esercizi,
            routines: schede.map { (name: $0.name, exercises: $0.orderedEntries.compactMap { $0.exercise?.id }) },
            query: ricerca)
    }

    // MARK: Vista

    var body: some View {
        // Calcolati una volta per ridisegno e passati alle parti che li usano.
        let nelloStorico = chiuse
        let esercizi = eserciziStorico(nelloStorico)
        let voci = vista == .sessioni ? vociStorico(nelloStorico, esercizi: esercizi) : []
        let anni = SessionHistory.years(voci, calendar: calendario)
        let anno = annoScelto ?? SessionHistory.defaultYear(voci, today: .now, calendar: calendario)
        VStack(spacing: 12) {
            TestataSezione(titolo: Sezione.storico.titolo) {
                if !anni.isEmpty && vista == .sessioni {
                    selettoreAnno(anni: anni, anno: anno)
                }
            }
            .padding(.horizontal, 20)
            SelettoreSegmenti(valori: [Vista.sessioni, .esercizi], selezione: $vista) { valore in
                valore == .sessioni ? "Sessioni" : "Esercizi"
            }
            .padding(.horizontal, 20)
            switch vista {
            case .sessioni:
                if voci.isEmpty {
                    vuoto("Le sessioni salvate compaiono qui.")
                } else {
                    elenco(SessionHistory.months(voci, year: anno, calendar: calendario))
                }
            case .esercizi:
                elencoEsercizi(esercizi)
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .destinazioniStorico()
    }

    // MARK: Esercizi

    @ViewBuilder
    private func elencoEsercizi(_ esercizi: [ExerciseHistory.Exercise<UUID>]) -> some View {
        if esercizi.isEmpty {
            vuoto("Gli esercizi fatti compaiono qui.")
        } else {
            let gruppi = gruppiEsercizi(esercizi)
            // Una sola ScrollView anche senza risultati: il campo di ricerca non si ricrea (la tastiera resta).
            ScrollView {
                if gruppi.isEmpty {
                    Text("Nessun esercizio trovato.")
                        .font(.body)
                        .foregroundStyle(Color.inchiostroTenue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(gruppi, id: \.title) { gruppo in
                            gruppoEsercizi(gruppo)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .barraFissa {
                campoRicerca
                    .padding(.horizontal, 20)
            }
        }
    }

    private var campoRicerca: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.inchiostroTenue)
            TextField("Cerca un esercizio", text: $ricerca)
                .font(.body)
                .foregroundStyle(Color.inchiostro)
                .autocorrectionDisabled()
                .submitLabel(.search)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Scheda: nome e «5 esercizi», poi le card degli esercizi nella pila.
    private func gruppoEsercizi(_ gruppo: ExerciseHistory.Group<UUID>) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(gruppo.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(gruppo.count)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
            }
            Pila {
                ForEach(gruppo.exercises, id: \.id) { esercizio in
                    NavigationLink(value: RottaStorico.esercizio(esercizio.id, indietro: "Esercizi")) {
                        cardEsercizio(esercizio)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Nome (con «nuovo» se il record è recente), sotto l'ultima volta e l'eventuale stallo;
    /// a destra il record personale.
    private func cardEsercizio(_ esercizio: ExerciseHistory.Exercise<UUID>) -> some View {
        let oggi = Date.now
        let fermo = esercizio.stalledWeeks(today: oggi, calendar: calendario)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(esercizio.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    if esercizio.isNewRecord(today: oggi, calendar: calendario) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy")
                                .font(.system(size: 11, weight: .semibold))
                            Text("nuovo")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.piastraTesto)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(Color.piastra, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .accessibilityLabel("record nuovo")
                    }
                }
                if let ultima = esercizio.last {
                    sottotitolo(ExerciseHistory.lastText(esercizio.text(ultima.lift), date: ultima.date, today: oggi, calendar: calendario),
                                fermo: fermo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let record = esercizio.record {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(esercizio.text(record.lift))
                        .font(.piastra(28))
                        .monospacedDigit()
                        .foregroundStyle(Color.inchiostro)
                        .lineLimit(1)
                    Text("record")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            FrecciaVoce()
        }
        .vocePila(altezza: 68)
        .accessibilityElement(children: .combine)
    }

    private func sottotitolo(_ testo: String, fermo: Int?) -> Text {
        var risultato = Text(testo).foregroundStyle(Color.inchiostroTenue)
        if let fermo {
            risultato = risultato
                + Text(" · ").foregroundStyle(Color.inchiostroTenue)
                + Text(ExerciseHistory.stallText(weeks: fermo)).fontWeight(.semibold).foregroundStyle(Color.inchiostro)
        }
        return risultato.font(.footnote)
    }

    /// «2026 ⌄»: capsula bianca con il menu degli anni con sessioni.
    private func selettoreAnno(anni: [Int], anno: Int) -> some View {
        Menu {
            Picker("Anno", selection: Binding(get: { anno }, set: { annoScelto = $0 })) {
                ForEach(anni, id: \.self) { valore in
                    Text(String(valore)).tag(valore)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(String(anno))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.inchiostro)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.foglio, in: Capsule())
        }
        .accessibilityLabel("Anno \(anno)")
    }

    private func vuoto(_ testo: String) -> some View {
        Text(testo)
            .font(.body)
            .foregroundStyle(Color.inchiostroTenue)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
    }

    private func elenco(_ mesi: [SessionHistory.Month<UUID>]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                ForEach(mesi, id: \.title) { mese in
                    Section {
                        ForEach(mese.weeks, id: \.start) { settimana in
                            separatore(settimana)
                            ForEach(settimana.days, id: \.date) { giorno in
                                riga(giorno)
                            }
                        }
                    } header: {
                        intestazione(mese)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    /// Mese come intestazione fissa: «Novembre 2026» e «11 sessioni».
    private func intestazione(_ mese: SessionHistory.Month<UUID>) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(mese.title)
                .font(.piastra(26))
                .foregroundStyle(Color.inchiostro)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(mese.count)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.lamiera.opacity(0.92))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.inchiostro.opacity(0.08))
                .frame(height: 1)
        }
    }

    /// Settimana come separatore: «16 – 22 novembre», linea, «1 sessione».
    private func separatore(_ settimana: SessionHistory.Week<UUID>) -> some View {
        HStack(spacing: 8) {
            Text(settimana.label)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
            Rectangle()
                .fill(Color.linea)
                .frame(height: 1)
            Text(settimana.count)
                .font(.footnote.weight(.medium))
        }
        .foregroundStyle(Color.inchiostroTenue)
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
    }

    /// Giorno a sinistra («LUN» e il numero), sessioni del giorno impilate a destra.
    private func riga(_ giorno: SessionHistory.Day<UUID>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Text(giorno.weekday)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
                Text(giorno.number)
                    .font(.piastra(26))
                    .foregroundStyle(Color.inchiostro)
            }
            .frame(width: 44)
            .padding(.top, 8)
            .accessibilityElement(children: .combine)
            Pila {
                ForEach(giorno.items, id: \.id) { voce in
                    voceSessione(voce)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func voceSessione(_ voce: SessionHistory.Item<UUID>) -> some View {
        NavigationLink(value: RottaStorico.sessione(voce.id, indietro: Sezione.storico.titolo)) {
            contenutoVoce(voce)
        }
        .buttonStyle(.plain)
    }

    private func contenutoVoce(_ voce: SessionHistory.Item<UUID>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(voce.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Text(voce.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if voce.hasRecord {
                Image(systemName: "trophy")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.inchiostro)
                    .accessibilityLabel("Record")
            }
            FrecciaVoce()
        }
        .vocePila(altezza: 56)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { StoricoView() }
        .modelContainer(for: Routine.self, inMemory: true)
}
