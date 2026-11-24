import SwiftUI
import SwiftData
import PernoCore

/// A Home (Allenati), nei due stati: oggi da fare e oggi fatto.
/// Calendario della settimana, «Oggi, giovedì» con la card della scheda di oggi, «Oppure» con le altre
/// schede e la sessione libera; a sessione fatta, numeri e «Prossimo allenamento».
struct HomeView: View {
    /// Sessione aperta in questo momento (anche ridotta).
    var sessioneViva: SessioneInCorso? = nil
    /// «Vedi nello storico»: apre il dettaglio della sessione nello Storico.
    var apriStorico: (WorkoutSession) -> Void = { _ in }
    var avvia: (Routine) -> Void = { _ in }
    var avviaLibera: () -> Void = {}
    var riprendi: (WorkoutSession) -> Void = { _ in }
    /// Riapre la schermata della sessione ridotta.
    var apriSessione: () -> Void = {}
    /// «Chiudi e vai al riepilogo» sulla card della sessione interrotta.
    var apriRiepilogo: (WorkoutSession) -> Void = { _ in }

    @Query(sort: \Routine.createdAt) private var schede: [Routine]
    @Query private var giorni: [PlanDay]
    @Query(sort: \WorkoutSession.startedAt) private var sessioni: [WorkoutSession]

    @Environment(\.modelContext) private var context
    @Environment(Backup.self) private var backup
    @State private var sessioneDaAnnullare: WorkoutSession?
    /// Letta solo per ridisegnare i kg quando cambia l'unità.
    @AppStorage(Impostazioni.unita) private var unita: WeightUnit = .kilograms

    private var calendario: Calendar { .current }

    // MARK: Dati

    private var oggi: Int { Weekday.of(.now, calendar: calendario) }

    /// Scheda per giorno (solo i giorni con una scheda).
    private var piano: [Int: UUID] {
        var piano: [Int: UUID] = [:]
        for giorno in giorni {
            if let scheda = giorno.routine { piano[giorno.weekday] = scheda.id }
        }
        return piano
    }

    private var pianoImpostato: Bool { !giorni.isEmpty }

    private var finite: [WorkoutSession] { sessioni.filter { $0.endedAt != nil } }

    private var ultimaVolta: [UUID: Date] {
        var date: [UUID: Date] = [:]
        for sessione in finite {
            if let id = sessione.routine?.id { date[id] = max(date[id] ?? .distantPast, sessione.startedAt) }
        }
        return date
    }

    private var proposta: Routine? {
        let id = TodayPlan.proposal(weekday: oggi, plan: piano, planIsSet: pianoImpostato,
                                    routines: schede.map(\.id), lastDone: ultimaVolta)
        return schede.first { $0.id == id }
    }

    /// Sessione che rende «fatto» oggi: con la scheda in programma oggi; senza piano o nei giorni
    /// di riposo, qualunque sessione iniziata oggi.
    private var sessioneDiOggi: WorkoutSession? {
        let diOggi = finite.filter { calendario.isDateInToday($0.startedAt) }
        if pianoImpostato, let inProgramma = piano[oggi] {
            return diOggi.last { $0.routine?.id == inProgramma }
        }
        return diOggi.last
    }

    private var giorniCalendario: [CalendarDay] {
        WeekCalendar.days(
            today: .now,
            plan: piano,
            names: Dictionary(schede.map { ($0.id, $0.name) }, uniquingKeysWith: { primo, _ in primo }),
            sessions: finite.map { FinishedSession(start: $0.startedAt, routine: $0.routine?.id, name: $0.routineName) },
            calendar: calendario
        )
    }

    // MARK: Vista

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TestataSezione(titolo: Sezione.allenati.titolo)

                if backup.fallito {
                    AvvisoBackup()
                        .padding(.top, 20)
                }

                CalendarioSettimana(giorni: giorniCalendario)
                    .padding(.top, 28)

                if let viva = sessioneViva {
                    sezione("Sessione in corso", sopra: 32) { cardInCorso(viva) }
                } else if let interrotta = sessioneInterrotta {
                    sezione("Sessione interrotta", sopra: 32) { cardInterrotta(interrotta) }
                    Text(ResumeText.footnote)
                        .font(.footnote)
                        .foregroundStyle(Color.inchiostroTenue)
                        .padding(.horizontal, 4)
                        .padding(.top, 20)
                } else if let sessione = sessioneDiOggi {
                    sezione(titoloOggi, sopra: 32) { cardFatto(sessione) }
                    if let prossimo = prossimoAllenamento {
                        sezione("Prossimo allenamento", sopra: 28) {
                            Pila { prossimo }
                        }
                    }
                } else if let scheda = proposta {
                    sezione(titoloOggi, sopra: 32) { cardDaFare(scheda) }
                    sezione("Oppure", sopra: 28) { altreScelte(escludendo: scheda) }
                } else {
                    sezione("Scegli un allenamento", sopra: 32) { altreScelte(escludendo: nil) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.lamiera)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Annullare la sessione?",
                            isPresented: Binding(get: { sessioneDaAnnullare != nil },
                                                 set: { if !$0 { sessioneDaAnnullare = nil } }),
                            titleVisibility: .visible,
                            presenting: sessioneDaAnnullare) { sessione in
            Button("Annulla sessione", role: .destructive) { annulla(sessione) }
            Button("Mantieni", role: .cancel) {}
        } message: { _ in
            Text("La sessione viene eliminata con tutti i set e oggi torna da fare.")
        }
    }

    /// «Annulla sessione» sulla card di oggi fatto: elimina la sessione (set e pause compresi).
    /// Il dialogo si chiude prima, poi la sessione si elimina (così nessuna vista legge una
    /// sessione già eliminata, come per il riepilogo e il dettaglio).
    private func annulla(_ sessione: WorkoutSession) {
        sessioneDaAnnullare = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            context.delete(sessione)
            try? context.save()
        }
    }

    private var titoloOggi: String { "Oggi, \(Weekday.name(oggi).lowercased())" }

    private func sezione<Content: View>(_ titolo: String, sopra: CGFloat,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titolo)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.inchiostro)
            content()
        }
        .padding(.top, sopra)
    }

    // MARK: Card

    /// Sessione rimasta aperta (app chiusa durante la sessione).
    private var sessioneInterrotta: WorkoutSession? {
        sessioni.last { $0.endedAt == nil }
    }

    private func avanzamento(_ sessione: WorkoutSession) -> [ExerciseProgress] {
        sessione.orderedExercises.map { esercizio in
            let lavoro = esercizio.orderedSets.filter { $0.kind != .approach }
            return ExerciseProgress(name: esercizio.name, done: lavoro.filter(\.isDone).count, total: lavoro.count)
        }
    }

    /// Una barretta per esercizio: piena = fatto, attenuata = iniziato, solo bordo = da fare.
    private func barrette(_ esercizi: [ExerciseProgress]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(esercizi.enumerated()), id: \.offset) { _, esercizio in
                Group {
                    switch esercizio.state {
                    case .done:
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.piastra)
                    case .started:
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.piastra.opacity(0.55))
                    case .notStarted:
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.inchiostro.opacity(0.22), lineWidth: 1.5)
                    }
                }
                .frame(height: 36)
            }
        }
        .accessibilityHidden(true)
    }

    /// Card «Sessione interrotta»: «Riprendi sessione» e «Chiudi e vai al riepilogo».
    private func cardInterrotta(_ sessione: WorkoutSession) -> some View {
        let esercizi = avanzamento(sessione)
        return VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessione.titolo)
                    .font(.piastra(48))
                    .foregroundStyle(Color.inchiostro)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(ResumeText.interrupted(at: sessione.lastActivityAt, done: sessione.setFatti,
                                            total: sessione.setPrevisti))
                    .font(.subheadline)
                    .foregroundStyle(Color.inchiostroTenue)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                barrette(esercizi)
                Text(ResumeText.summary(esercizi))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.inchiostroTenue)
            }
            PulsanteGiallo(titolo: "Riprendi sessione") { riprendi(sessione) }
            Button {
                apriRiepilogo(sessione)
            } label: {
                Text("Chiudi e vai al riepilogo")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.inchiostro)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, -8)
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Card della sessione ridotta: torna alla schermata della sessione. Ha il colore del dock in quel
    /// momento (riscaldamento arancio, cambio esercizio grafite, set in corso foglio, recupero blu) con
    /// l'etichetta della fase, la durata della sessione in alto a destra e i set dell'esercizio di adesso
    /// (fatti con il valore, da fare con l'obiettivo). Richiesta dell'utente del 24/11.
    private func cardInCorso(_ viva: SessioneInCorso) -> some View {
        let esercizi = avanzamento(viva.sessione)
        let conto = viva.setDiLavoroTotali
        let fase = FaseCard(viva)
        return TimelineView(.periodic(from: .now, by: 1)) { contesto in
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(fase.etichetta)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(fase.tenue)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(SessionText.clock(contesto.date.timeIntervalSince(viva.sessione.startedAt)))
                            .font(.piastra(28))
                            .monospacedDigit()
                            .foregroundStyle(fase.testo)
                            .accessibilityLabel("Durata della sessione")
                    }
                    Text(viva.sessione.titolo)
                        .font(.piastra(48))
                        .foregroundStyle(fase.testo)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(ResumeText.inProgress(done: conto.fatti, total: conto.totale))
                        .font(.subheadline)
                        .foregroundStyle(fase.tenue)
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let indice = viva.indiceEsercizio, !viva.daScegliere {
                        setDiAdesso(viva, esercizio: indice, fase: fase)
                    }
                    Text(ResumeText.summary(esercizi))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(fase.tenue)
                }
                PulsanteGiallo(titolo: "Torna alla sessione", azione: apriSessione)
            }
            .padding(.top, 20)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fase.sfondo, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    /// Set dell'esercizio di adesso: fatti = fondo pieno con peso × ripetizioni fatti; da fare = solo bordo
    /// con l'obiettivo; quello di adesso con il bordo pieno.
    private func setDiAdesso(_ viva: SessioneInCorso, esercizio indice: Int, fase: FaseCard) -> some View {
        let sets = viva.set[indice]
        let numeri = SessionText.numbers(sets.map(\.kind))
        let adesso = viva.indiceEsercizio == indice && viva.setCorrente != nil ? viva.macchina.setIndex : nil
        return VStack(alignment: .leading, spacing: 8) {
            Text(viva.esercizi[indice].name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(fase.testo)
                .lineLimit(1)
            FilaACapo(spazio: 4) {
                ForEach(Array(sets.enumerated()), id: \.offset) { posizione, set in
                    let fatto = set.isDone && set.weight != nil && set.reps != nil
                    let valore = fatto
                        ? SessionText.weightReps(set.weight ?? 0, set.reps ?? 0)
                        : SessionText.weightReps(set.targetWeight, set.targetReps)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(SessionText.shortName(set.kind, numeri[posizione]))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(fase.tenue)
                        Text(valore)
                            .font(.piastra(20))
                            .monospacedDigit()
                            .foregroundStyle(fatto ? fase.testo : fase.tenue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        if fatto {
                            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fase.testo.opacity(0.14))
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(fase.testo.opacity(posizione == adesso ? 0.9 : 0.25),
                                              lineWidth: posizione == adesso ? 2 : 1.5)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(fatto ? "fatto" : "obiettivo")
                }
            }
        }
    }

    private func cardDaFare(_ scheda: Routine) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scheda.name)
                    .font(.piastra(48))
                    .foregroundStyle(Color.inchiostro)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text(scheda.elencoConDurata)
                    .font(.subheadline)
                    .foregroundStyle(Color.inchiostroTenue)
            }
            PulsanteGiallo(titolo: "Inizia \(scheda.name)", attivo: !scheda.entries.isEmpty) {
                avvia(scheda)
            }
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func cardFatto(_ sessione: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.piastra)
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.piastraTesto)
                    }
                Text("Fatto")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inchiostroTenue)
            }
            Text(sessione.titolo)
                .font(.piastra(48))
                .foregroundStyle(Color.inchiostro)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, -8)
            HStack(alignment: .top, spacing: 12) {
                numero(HomeText.duration(sessione.durata), "durata")
                numero("\(sessione.setFatti) set", "su \(sessione.setPrevisti)")
                numero(HomeText.volume(Units.unit.fromKilograms(sessione.chiliSollevati)), "\(Units.unit.symbol) sollevati")
            }
            PulsanteSecondario(titolo: "Vedi nello storico") { apriStorico(sessione) }
            Button {
                sessioneDaAnnullare = sessione
            } label: {
                Text("Annulla sessione")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.errore)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, -8)
        }
        .padding(.top, 20)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.foglio, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func numero(_ valore: String, _ etichetta: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(valore)
                .font(.piastra(30))
                .monospacedDigit()
                .foregroundStyle(Color.inchiostro)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(etichetta)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.inchiostroTenue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Elenchi

    /// Le altre schede con «Inizia», poi la sessione libera.
    private func altreScelte(escludendo esclusa: Routine?) -> some View {
        Pila {
            ForEach(schede.filter { $0.id != esclusa?.id }) { scheda in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scheda.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.inchiostro)
                        Text(scheda.riassunto)
                            .font(.footnote)
                            .foregroundStyle(Color.inchiostroTenue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PulsanteSecondario(titolo: "Inizia", altezza: 44, riempi: false) {
                        avvia(scheda)
                    }
                }
                .vocePila()
            }
            Button {
                avviaLibera()
            } label: {
                VocePila(titolo: "Sessione libera", sottotitolo: "Scegli gli esercizi strada facendo")
            }
            .buttonStyle(.plain)
        }
    }

    /// «Gambe — Sabato, 4 esercizi» (solo con il piano impostato).
    private var prossimoAllenamento: VocePila? {
        guard let prossimo = TodayPlan.next(after: oggi, plan: piano),
              let scheda = schede.first(where: { $0.id == prossimo.routine }) else { return nil }
        let giorno = prossimo.weekday
        let quanti = scheda.orderedEntries.count
        let esercizi = quanti == 0 ? "nessun esercizio" : (quanti == 1 ? "1 esercizio" : "\(quanti) esercizi")
        return VocePila(titolo: scheda.name, sottotitolo: "\(Weekday.name(giorno)), \(esercizi)", freccia: false)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(Backup())
    .modelContainer(for: Routine.self, inMemory: true)
}

/// Colori ed etichetta della card «Sessione in corso»: gli stessi del dock nella fase di adesso.
private struct FaseCard {
    let etichetta: String
    let sfondo: Color
    let testo: Color
    let tenue: Color

    @MainActor
    init(_ viva: SessioneInCorso) {
        let numero = viva.numeroSetCorrente
        let tipo = viva.setCorrente?.kind ?? .work
        let valori: (String, Color, Color, Color)
        switch viva.fase {
        case .warmUp:
            valori = ("Riscaldamento in corso", .riscaldamento, .white, .riscaldamentoTenue)
        case .changeover:
            valori = ("Cambio esercizio", .piastra, .white, .piastraTenue)
        case let .countdown(_, _, pausa):
            valori = (pausa == .rest ? "Recupero finito" : "Cambio esercizio", .piastra, .white, .piastraTenue)
        case .inSet:
            valori = (SessionText.inProgress(tipo, numero), .foglio, .inchiostro, .inchiostroTenue)
        case .rest:
            valori = ("Recupero", .recupero, .white, .recuperoTenue)
        case .finished:
            valori = ("Tutti i set fatti", .piastra, .white, .piastraTenue)
        }
        etichetta = valori.0
        sfondo = valori.1
        testo = valori.2
        tenue = valori.3
    }
}
