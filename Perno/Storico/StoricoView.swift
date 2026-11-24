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

    private var vociStorico: [SessionHistory.Item<UUID>] {
        chiuse.map { sessione in
            SessionHistory.Item(
                id: sessione.id,
                start: sessione.startedAt,
                title: sessione.titolo,
                duration: sessione.durata,
                sets: sessione.setFatti,
                isFree: sessione.isFree,
                exercises: sessione.exercises.filter { $0.sets.contains(where: \.isDone) }.count,
                hasRecord: !sessione.record.isEmpty)
        }
    }

    /// Esercizi fatti nelle sessioni dello storico, con i set di lavoro di ogni volta.
    private var eserciziStorico: [ExerciseHistory.Exercise<UUID>] {
        var volte: [UUID: (nome: String, voci: [ExerciseHistory.Entry])] = [:]
        for sessione in chiuse {
            for voce in sessione.exercises {
                guard let esercizio = voce.exercise else { continue }
                let alzate = voce.sets.compactMap { set -> SessionSummary.Lift? in
                    guard set.isDone, set.kind != .approach, let peso = set.weight, let ripetizioni = set.reps else { return nil }
                    return SessionSummary.Lift(weight: peso, reps: ripetizioni)
                }
                guard !alzate.isEmpty else { continue }
                volte[esercizio.id, default: (esercizio.name, [])].voci
                    .append(ExerciseHistory.Entry(date: sessione.startedAt, lifts: alzate))
            }
        }
        return volte.map { ExerciseHistory.Exercise(id: $0.key, name: $0.value.nome, entries: $0.value.voci) }
    }

    private var gruppiEsercizi: [ExerciseHistory.Group<UUID>] {
        ExerciseHistory.groups(
            exercises: eserciziStorico,
            routines: schede.map { (name: $0.name, exercises: $0.orderedEntries.compactMap { $0.exercise?.id }) },
            query: ricerca)
    }

    // MARK: Vista

    var body: some View {
        let voci = vociStorico
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
                esercizi
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
    private var esercizi: some View {
        if eserciziStorico.isEmpty {
            vuoto("Gli esercizi fatti compaiono qui.")
        } else {
            let gruppi = gruppiEsercizi
            VStack(spacing: 0) {
                campoRicerca
                    .padding(.horizontal, 20)
                if gruppi.isEmpty {
                    vuoto("Nessun esercizio trovato.")
                        .padding(.top, 12)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(gruppi, id: \.title) { gruppo in
                                gruppoEsercizi(gruppo)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                }
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
                    sottotitolo(ExerciseHistory.lastText(ultima.lift, date: ultima.date, today: oggi, calendar: calendario),
                                fermo: fermo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let record = esercizio.record {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(SessionText.weightReps(record.lift.weight, record.lift.reps))
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
