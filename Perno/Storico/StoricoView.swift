import SwiftUI
import SwiftData
import PernoCore

/// Storico (tavola «L Sessioni»): selettore dell'anno, Sessioni / Esercizi, una lista sola con il mese
/// come intestazione fissa, la settimana come separatore con il conteggio e il giorno a sinistra
/// con più sessioni impilate. Riga = durata e set, coppa se c'è un record; niente volume.
/// Il tocco su una riga apre il Dettaglio sessione.
struct StoricoView: View {
    enum Vista: Hashable {
        case sessioni
        case esercizi
    }

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessioni: [WorkoutSession]
    @Environment(\.modelContext) private var context
    @State private var vista: Vista = .sessioni
    /// Anno scelto; `nil` = il più recente con sessioni.
    @State private var annoScelto: Int?

    private var calendario: Calendar { .current }

    // MARK: Dati

    /// Sessioni nello storico: chiuse, escluse quelle chiuse da sole e non ancora salvate.
    private var chiuse: [WorkoutSession] {
        sessioni.filter { $0.endedAt != nil && !($0.closedAutomatically && !$0.isSaved) }
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

    // MARK: Vista

    var body: some View {
        let voci = vociStorico
        let anni = SessionHistory.years(voci, calendar: calendario)
        let anno = annoScelto ?? SessionHistory.defaultYear(voci, today: .now, calendar: calendario)
        VStack(spacing: 12) {
            TestataSezione(titolo: Sezione.storico.titolo) {
                if !anni.isEmpty {
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
                vuoto("Arriva in una delle prossime build.")
            }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: UUID.self) { id in
            if let sessione = sessioni.first(where: { $0.id == id }) {
                DettaglioSessioneView(sessione: sessione) { elimina(sessione) }
            }
        }
    }

    /// Elimina dopo la chiusura del dettaglio (così nessuna vista legge una sessione eliminata).
    private func elimina(_ sessione: WorkoutSession) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            context.delete(sessione)
            try? context.save()
        }
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
        NavigationLink(value: voce.id) {
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
