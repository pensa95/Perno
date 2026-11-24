import SwiftUI
import SwiftData
import Charts
import PernoCore

/// Dettaglio esercizio (tavola «M Dettaglio esercizio»): scheda e attrezzo sopra il nome, blocco
/// grafite del record personale, ultima volta / sessioni / recupero abituale, grafico del massimale
/// stimato (3 mesi, 6 mesi, 1 anno, tutto), regolazioni e promemoria, ultime sessioni con «Vedi tutte».
/// Si apre dallo Storico, dal dettaglio sessione, dalla Libreria e da Progressi in sessione.
struct DettaglioEsercizioView: View {
    let esercizio: Exercise
    /// Nome della schermata a cui torna la freccia.
    var indietro = "Esercizi"

    @Environment(\.dismiss) private var dismiss
    @State private var periodo: ExerciseDetail.Range = .sixMonths
    /// Letta solo per ridisegnare i pesi quando cambia l'unità.
    @AppStorage(Impostazioni.unita) private var unita: WeightUnit = .kilograms

    /// Sessioni mostrate sotto «Sessioni» prima di «Vedi tutte».
    private static let ultimeSessioni = 4

    // MARK: Dati

    /// Prima voce di una scheda con questo esercizio: dà il nome della scheda, le regolazioni e i promemoria.
    private var voceScheda: RoutineEntry? {
        esercizio.routineEntries
            .filter { $0.routine != nil }
            .sorted { ($0.routine?.createdAt ?? .distantPast) < ($1.routine?.createdAt ?? .distantPast) }
            .first
    }

    /// Regolazioni e promemoria: quelli della scheda, altrimenti quelli dell'ultima volta.
    private var regolazioni: (setup: String, promemoria: [String]) {
        if let voce = voceScheda {
            return (voce.setup.trimmingCharacters(in: .whitespacesAndNewlines), Cues.split(voce.cues))
        }
        let ultima = esercizio.sessionExercises
            .filter { $0.session?.nelloStorico == true }
            .max { ($0.session?.startedAt ?? .distantPast) < ($1.session?.startedAt ?? .distantPast) }
        return (ultima?.setup.trimmingCharacters(in: .whitespacesAndNewlines) ?? "", Cues.split(ultima?.cues ?? ""))
    }

    var body: some View {
        let storico = esercizio.storico
        let volte = esercizio.volteNelloStorico
        let record = ExerciseDetail.recordDates(storico)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PulsanteIndietro(titolo: indietro) { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                titolo.padding(.top, 16)
                if let migliore = storico.record {
                    bloccoRecord(migliore.lift, data: migliore.date).padding(.top, 20)
                }
                numeri(storico).padding(.top, 16)
                grafico(storico).padding(.top, 28)
                sezioneRegolazioni
                sessioni(volte, record: record)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.lamiera.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Titolo e record

    private var titolo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ExerciseDetail.overline(routine: voceScheda?.routine?.name, equipment: esercizio.equipment))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
            Text(esercizio.name)
                .font(.piastra(44))
                .foregroundStyle(Color.inchiostro)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Blocco grafite: coppa sul quadrato giallo, «Record personale», «65 × 8», data e massimale stimato.
    private func bloccoRecord(_ alzata: SessionSummary.Lift, data: Date) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.suPerno)
                .frame(width: 48, height: 48)
                .background(Color.perno, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text("Record personale")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.piastraTenue)
                Text(SessionText.weightReps(alzata.weight, alzata.reps))
                    .font(.piastra(48))
                    .monospacedDigit()
                    .foregroundStyle(Color.piastraTesto)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(ExerciseDetail.recordDetail(alzata, date: data))
                    .font(.footnote)
                    .foregroundStyle(Color.piastraTenue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.piastra, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Numeri

    private func numeri(_ storico: ExerciseHistory.Exercise<UUID>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            numero(storico.last.map { SessionText.weightReps($0.lift.weight, $0.lift.reps) } ?? "—", "ultima volta")
            numero(String(ExerciseDetail.sessionCount(storico)), "sessioni")
            numero(esercizio.recuperoAbituale.map { HomeText.duration($0) } ?? "—", "recupero abituale")
        }
    }

    private func numero(_ valore: String, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(valore)
                .font(.piastra(26))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(etichetta)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Grafico

    private func grafico(_ storico: ExerciseHistory.Exercise<UUID>) -> some View {
        let punti = ExerciseDetail.points(ExerciseDetail.points(storico), in: periodo, today: .now)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Massimale stimato")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Spacer(minLength: 8)
                if let variazione = ExerciseDetail.change(punti, range: periodo) {
                    Text(variazione)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.inchiostroTenue)
                }
            }
            SelettoreSegmenti(valori: ExerciseDetail.Range.allCases, selezione: $periodo) { $0.label }
            Group {
                if punti.count >= 2 {
                    curva(punti)
                } else {
                    Text("Servono almeno due sessioni in questo periodo.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inchiostroTenue)
                        .frame(maxWidth: .infinity, minHeight: 120)
                }
            }
            .padding(.top, 12)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.bottom, 4)
            .background(Color.foglio, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    /// Linea inchiostro del massimale stimato; l'ultimo punto col perno giallo. Asse dei valori a destra.
    private func curva(_ punti: [ExerciseDetail.Point]) -> some View {
        let valori = punti.map { Units.unit.fromKilograms($0.estimatedMax) }
        let minimo = valori.min() ?? 0
        let massimo = valori.max() ?? 0
        let margine = max(2, (massimo - minimo) * 0.15)
        return Chart {
            ForEach(Array(punti.enumerated()), id: \.offset) { _, punto in
                LineMark(x: .value("Data", punto.date),
                         y: .value("Massimale", Units.unit.fromKilograms(punto.estimatedMax)))
                    .foregroundStyle(Color.inchiostro)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            if let ultimo = punti.last {
                PointMark(x: .value("Data", ultimo.date),
                          y: .value("Massimale", Units.unit.fromKilograms(ultimo.estimatedMax)))
                    .symbol {
                        Circle()
                            .fill(Color.perno)
                            .frame(width: 10, height: 10)
                            .overlay { Circle().stroke(Color.inchiostro, lineWidth: 2) }
                    }
            }
        }
        .chartYScale(domain: (minimo - margine)...(massimo + margine))
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { valore in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                    .foregroundStyle(Color.linea)
                AxisValueLabel {
                    if let numero = valore.as(Double.self) {
                        Text(String(Int(numero.rounded())))
                            .font(.caption2)
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { valore in
                AxisValueLabel {
                    if let data = valore.as(Date.self) {
                        Text(Self.meseCorto(data))
                            .font(.caption2)
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                }
            }
        }
        .frame(height: 180)
        .accessibilityElement()
        .accessibilityLabel(accessibilita(valori))
    }

    private static func meseCorto(_ data: Date) -> String {
        let mesi = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]
        let mese = Calendar.current.component(.month, from: data)
        return mesi[max(0, min(11, mese - 1))]
    }

    private func accessibilita(_ valori: [Double]) -> String {
        guard let primo = valori.first, let ultimo = valori.last else { return "Massimale stimato" }
        return "Massimale stimato da \(Int(primo.rounded())) a \(Int(ultimo.rounded())) \(Units.unit.symbol), \(periodo.label)"
    }

    // MARK: Regolazioni

    @ViewBuilder
    private var sezioneRegolazioni: some View {
        let voci = regolazioni
        if !voci.setup.isEmpty || !voci.promemoria.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Regolazioni")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                Pila {
                    if !voci.setup.isEmpty {
                        HStack(spacing: 12) {
                            Image(systemName: "wrench.adjustable")
                                .font(.system(size: 17, weight: .semibold))
                            Text(voci.setup)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Color.inchiostro)
                        .vocePila()
                    }
                    ForEach(voci.promemoria, id: \.self) { voce in
                        HStack(spacing: 12) {
                            Image(systemName: "pin")
                                .font(.system(size: 17, weight: .semibold))
                            Text(voce)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Color.inchiostroTenue)
                        .vocePila()
                    }
                }
            }
            .padding(.top, 28)
        }
    }

    // MARK: Sessioni

    @ViewBuilder
    private func sessioni(_ volte: [(sessione: WorkoutSession, alzate: [SessionSummary.Lift])], record: Set<Date>) -> some View {
        if !volte.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Sessioni")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.inchiostro)
                    Spacer(minLength: 8)
                    if volte.count > Self.ultimeSessioni {
                        NavigationLink(value: RottaStorico.sessioniEsercizio(esercizio.id, indietro: esercizio.name)) {
                            Text("Vedi tutte")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.inchiostro)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Pila {
                    ForEach(Array(volte.prefix(Self.ultimeSessioni).enumerated()), id: \.offset) { _, volta in
                        RigaSessioneEsercizio(sessione: volta.sessione, alzate: volta.alzate,
                                              record: record.contains(volta.sessione.startedAt),
                                              indietro: esercizio.name)
                    }
                }
            }
            .padding(.top, 28)
        }
    }
}

/// Riga di una sessione nel dettaglio esercizio: «gio 19 nov», i set di lavoro, coppa se c'è un record.
/// Il tocco apre il dettaglio della sessione.
struct RigaSessioneEsercizio: View {
    let sessione: WorkoutSession
    let alzate: [SessionSummary.Lift]
    let record: Bool
    let indietro: String

    var body: some View {
        NavigationLink(value: RottaStorico.sessione(sessione.id, indietro: indietro)) {
            HStack(spacing: 12) {
                Text(ExerciseDetail.rowDate(sessione.startedAt))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .frame(width: 84, alignment: .leading)
                Text(ExerciseDetail.rowSets(alzate))
                    .font(.piastra(18, peso: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if record {
                    Image(systemName: "trophy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inchiostro)
                        .accessibilityLabel("Record")
                }
                FrecciaVoce()
            }
            .vocePila(altezza: 52)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// «Vedi tutte»: tutte le sessioni dell'esercizio, dalla più recente.
struct SessioniEsercizioView: View {
    let esercizio: Exercise
    var indietro: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let volte = esercizio.volteNelloStorico
        let record = ExerciseDetail.recordDates(esercizio.storico)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PulsanteIndietro(titolo: indietro) { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Text("Sessioni")
                    .font(.piastra(40))
                    .foregroundStyle(Color.inchiostro)
                    .padding(.top, 12)
                    .accessibilityAddTraits(.isHeader)
                Text(esercizio.name)
                    .font(.subheadline)
                    .foregroundStyle(Color.inchiostroTenue)
                Pila {
                    ForEach(Array(volte.enumerated()), id: \.offset) { _, volta in
                        RigaSessioneEsercizio(sessione: volta.sessione, alzate: volta.alzate,
                                              record: record.contains(volta.sessione.startedAt),
                                              indietro: "Sessioni")
                    }
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(Color.lamiera.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}
