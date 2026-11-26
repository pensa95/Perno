import Foundation

// MARK: - Live Activity e Dynamic Island

/// Colore della card (come il dock): riscaldamento arancio, cambio grafite, set chiaro, recupero blu,
/// tutti i set fatti chiaro con il pulsante giallo.
public enum LiveActivityTone: String, Codable, Hashable, Sendable {
    case warmUp
    case changeover
    case inSet
    case rest
    case finished
}

/// Azione di un pulsante della card. `open` apre la sessione nell'app («Scegli esercizi»,
/// «Vai al riepilogo»); le altre si eseguono senza sbloccare.
public enum LiveActivityAction: String, Codable, Hashable, Sendable, CaseIterable {
    case endWarmUp
    case skipWarmUp
    case start
    case setDone
    case postpone
    case addFifteen
    case open
    /// «Vai a Lat machine» dopo l'ultimo set di un esercizio (UI v6): porta al cambio esercizio.
    case goToNext
}

public struct LiveActivityButton: Codable, Hashable, Sendable {
    public var title: String
    public var action: LiveActivityAction

    public init(_ title: String, _ action: LiveActivityAction) {
        self.title = title
        self.action = action
    }
}

/// Contenuto della card sul blocco schermo e della Dynamic Island. I testi sono già pronti:
/// l'estensione li mostra e basta. I tempi sono date assolute, così il sistema li fa scorrere
/// da solo anche con l'app sospesa.
public struct LiveActivityState: Codable, Hashable, Sendable {
    public var tone: LiveActivityTone
    /// Etichetta della fase, come nel dock («Recupero, di solito 2:10»).
    public var label: String
    /// Nome della scheda («Upper body», «Sessione libera»).
    public var routine: String
    /// Esercizio («Chest press», «Poi Chest press», «Nessun esercizio»).
    public var title: String
    /// «Set 2», «Set 2, obiettivo», «3 set», «14 set su 14».
    public var setLabel: String
    /// «62,5 × 10» (in Barlow Condensed accanto a `setLabel`).
    public var setValue: String?
    /// Inizio del tempo che conta in avanti (e della barra del recupero alla rovescia).
    public var timerStart: Date
    /// Fine del conto alla rovescia (recupero alla rovescia, 3-2-1); `nil` = cronometro.
    public var timerEnd: Date?
    /// «+» davanti al tempo in più dopo lo zero del recupero.
    public var timerPrefix: String?
    /// Barra di avanzamento del recupero alla rovescia (da `timerStart` a `timerEnd`).
    public var showsProgress: Bool
    /// Timer grande (3-2-1).
    public var bigTimer: Bool
    public var primary: LiveActivityButton?
    public var secondary: LiveActivityButton?

    public init(tone: LiveActivityTone, label: String, routine: String, title: String, setLabel: String,
                setValue: String?, timerStart: Date, timerEnd: Date?, timerPrefix: String?,
                showsProgress: Bool, bigTimer: Bool, primary: LiveActivityButton?,
                secondary: LiveActivityButton?) {
        self.tone = tone
        self.label = label
        self.routine = routine
        self.title = title
        self.setLabel = setLabel
        self.setValue = setValue
        self.timerStart = timerStart
        self.timerEnd = timerEnd
        self.timerPrefix = timerPrefix
        self.showsProgress = showsProgress
        self.bigTimer = bigTimer
        self.primary = primary
        self.secondary = secondary
    }
}

/// Quello che serve della sessione aperta per riempire la card.
public struct LiveActivityInput: Sendable {
    public var phase: SessionPhase
    public var routine: String
    /// Esercizio di adesso (nel riscaldamento: il primo dell'ordine di oggi).
    public var exercise: String?
    /// Set di lavoro dell'esercizio (per «Poi Chest press · 3 set» nel riscaldamento).
    public var exerciseWorkSets: Int
    public var setKind: SetKind?
    public var setNumber: Int
    public var weight: Double?
    public var reps: Int?
    public var restMode: RestMode
    public var restDuration: TimeInterval
    public var restLabel: String
    public var countdownSeconds: Int
    public var canPostpone: Bool
    /// Sessione libera senza esercizio da fare: «Scegli esercizi».
    public var awaitingChoice: Bool
    public var sessionStart: Date
    public var workSetsDone: Int
    public var workSetsTotal: Int
    /// Set a tempo (UI v5): durata obiettivo in secondi; `nil` per i set a ripetizioni.
    public var targetSeconds: Int?
    /// Esercizio a tempo con «Con peso» (senza, il valore è solo «0:45»).
    public var withWeight: Bool
    /// Fine dell'ultimo set di un esercizio (UI v6): si resta sull'esercizio finito, `exercise` è il
    /// prossimo e la card propone «Vai a …». `nextDetail` è «3 set da 8 a 12».
    public var awaitingNext: Bool
    public var nextDetail: String?

    public init(phase: SessionPhase, routine: String, exercise: String?, exerciseWorkSets: Int,
                setKind: SetKind?, setNumber: Int, weight: Double?, reps: Int?, restMode: RestMode,
                restDuration: TimeInterval, restLabel: String, countdownSeconds: Int, canPostpone: Bool,
                awaitingChoice: Bool, sessionStart: Date, workSetsDone: Int, workSetsTotal: Int,
                targetSeconds: Int? = nil, withWeight: Bool = true, awaitingNext: Bool = false,
                nextDetail: String? = nil) {
        self.awaitingNext = awaitingNext
        self.nextDetail = nextDetail
        self.phase = phase
        self.routine = routine
        self.exercise = exercise
        self.exerciseWorkSets = exerciseWorkSets
        self.setKind = setKind
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.restMode = restMode
        self.restDuration = restDuration
        self.restLabel = restLabel
        self.countdownSeconds = countdownSeconds
        self.canPostpone = canPostpone
        self.awaitingChoice = awaitingChoice
        self.sessionStart = sessionStart
        self.workSetsDone = workSetsDone
        self.workSetsTotal = workSetsTotal
        self.targetSeconds = targetSeconds
        self.withWeight = withWeight
    }
}

public enum LiveActivityText {
    public static let warmUpLabel = "Riscaldamento in corso"
    public static let warmUpDone = "Riscaldamento fatto"
    public static let skip = "Salta"
    public static let changeover = "Cambio esercizio"
    public static let postpone = "Rimanda"
    public static let addFifteen = "+15 s"
    public static let overtime = "Recupero finito, tempo in più"
    public static let noExercise = "Nessun esercizio"
    public static let freeSession = "Sessione libera"
    public static let chooseExercises = "Scegli esercizi"
    public static let allDone = "Tutti i set fatti"
    public static let toSummary = "Vai al riepilogo"
    /// Notifica a zero del recupero alla rovescia.
    public static let restOverTitle = "Recupero finito"

    /// «Set 2 di Chest press, 62,5 × 10.»
    public static func restOverBody(setName: String, exercise: String, value: String?) -> String {
        let base = "\(setName) di \(exercise)"
        guard let value else { return base + "." }
        return "\(base), \(value)."
    }

    /// Valore del set accanto al nome: «62,5 × 10», a tempo «10 × 0:45» o «0:45».
    public static func value(for input: LiveActivityInput) -> String? {
        if let seconds = input.targetSeconds {
            return TimedText.value(seconds: seconds, weight: input.withWeight ? (input.weight ?? 0) : nil)
        }
        guard let weight = input.weight, let reps = input.reps else { return nil }
        return SessionText.weightReps(weight, reps)
    }

    /// Contenuto della card in questo momento. `now` serve solo al recupero alla rovescia,
    /// per passare a «tempo in più» dopo lo zero.
    public static func state(for input: LiveActivityInput, now: Date) -> LiveActivityState {
        let kind = input.setKind ?? .work
        let setName = SessionText.shortName(kind, input.setNumber)
        let value = Self.value(for: input)
        let exercise = input.exercise ?? input.routine

        func make(_ tone: LiveActivityTone, label: String, title: String, setLabel: String, setValue: String?,
                  start: Date, end: Date? = nil, prefix: String? = nil, progress: Bool = false,
                  big: Bool = false, primary: LiveActivityButton?, secondary: LiveActivityButton? = nil)
            -> LiveActivityState {
            LiveActivityState(tone: tone, label: label, routine: input.routine, title: title,
                              setLabel: setLabel, setValue: setValue, timerStart: start, timerEnd: end,
                              timerPrefix: prefix, showsProgress: progress, bigTimer: big,
                              primary: primary, secondary: secondary)
        }

        switch input.phase {
        case let .warmUp(since):
            let next = input.exercise.map { "Poi \($0)" } ?? input.routine
            let sets = input.exercise == nil ? "" : "\(input.exerciseWorkSets) set"
            return make(.warmUp, label: warmUpLabel, title: next, setLabel: sets, setValue: nil, start: since,
                        primary: LiveActivityButton(warmUpDone, .endWarmUp),
                        secondary: LiveActivityButton(skip, .skipWarmUp))

        case let .changeover(since) where input.awaitingNext && input.exercise != nil:
            // Fine dell'ultimo set di un esercizio: niente «Inizia», si va al cambio con «Vai a …».
            let next = input.exercise ?? ""
            return make(.changeover, label: changeover, title: NextExerciseText.then(next),
                        setLabel: input.nextDetail ?? "", setValue: nil, start: since,
                        primary: LiveActivityButton(NextExerciseText.goTo(next), .goToNext))

        case let .changeover(since):
            if input.awaitingChoice || input.exercise == nil {
                return make(.changeover, label: changeover, title: noExercise, setLabel: freeSession,
                            setValue: nil, start: since,
                            primary: LiveActivityButton(chooseExercises, .open))
            }
            return make(.changeover, label: changeover, title: exercise, setLabel: setName, setValue: value,
                        start: since,
                        primary: LiveActivityButton(SessionText.startTitle(kind, input.setNumber), .start),
                        secondary: input.canPostpone ? LiveActivityButton(postpone, .postpone) : nil)

        case let .countdown(since, pauseStart, pauseKind):
            // Stessa fine della schermata: tocco + anticipo + 3 s (vedi `Countdown`).
            let end = Countdown.start(since: since).addingTimeInterval(TimeInterval(input.countdownSeconds))
            return make(pauseKind == .rest ? .rest : .changeover,
                        label: SessionText.countdownTitle(kind, input.setNumber),
                        title: exercise, setLabel: setName, setValue: value,
                        start: pauseStart, end: end, big: true, primary: nil)

        case let .inSet(since) where input.targetSeconds != nil:
            // Set a tempo: conto alla rovescia fino allo zero, con la barra (a zero si chiude da solo).
            let end = since.addingTimeInterval(TimeInterval(input.targetSeconds ?? 0))
            return make(.inSet, label: TimedText.inProgress(kind, input.setNumber), title: exercise,
                        setLabel: "\(setName), obiettivo", setValue: value, start: since, end: end,
                        progress: true,
                        primary: LiveActivityButton(SessionText.doneTitle(kind, input.setNumber), .setDone))

        case let .inSet(since):
            return make(.inSet, label: SessionText.inProgress(kind, input.setNumber), title: exercise,
                        setLabel: "\(setName), obiettivo", setValue: value, start: since,
                        primary: LiveActivityButton(SessionText.doneTitle(kind, input.setNumber), .setDone))

        case let .rest(since):
            let primary = LiveActivityButton(SessionText.startTitle(kind, input.setNumber), .start)
            guard input.restMode == .countdown else {
                return make(.rest, label: input.restLabel, title: exercise, setLabel: setName, setValue: value,
                            start: since, primary: primary)
            }
            let end = since.addingTimeInterval(input.restDuration)
            if now < end {
                return make(.rest, label: input.restLabel, title: exercise, setLabel: setName, setValue: value,
                            start: since, end: end, progress: true, primary: primary,
                            secondary: LiveActivityButton(addFifteen, .addFifteen))
            }
            return make(.rest, label: overtime, title: exercise, setLabel: setName, setValue: value,
                        start: since, end: end, prefix: "+", progress: true, primary: primary)

        case .finished:
            return make(.finished, label: allDone, title: input.routine,
                        setLabel: "\(input.workSetsDone) set su \(input.workSetsTotal)", setValue: nil,
                        start: input.sessionStart, primary: LiveActivityButton(toSummary, .open))
        }
    }

    /// Momento in cui la card deve cambiare da sola (zero del recupero alla rovescia), se c'è.
    public static func nextChange(for input: LiveActivityInput, now: Date) -> Date? {
        guard case let .rest(since) = input.phase, input.restMode == .countdown else { return nil }
        let end = since.addingTimeInterval(input.restDuration)
        return end > now ? end : nil
    }
}

/// Fine dell'ultimo set di un esercizio (UI v6, tavola 6): dock grafite «Cambio esercizio» con
/// «Poi Lat machine, 3 set da 8 a 12» e il pulsante «Vai a Lat machine».
public enum NextExerciseText {
    /// «3 set da 8 a 12» (stesso intervallo: «3 set da 10»); a tempo «3 set da 0:45».
    public static func detail(sets: Int, repsMin: Int, repsMax: Int, seconds: Int? = nil) -> String {
        if let seconds { return "\(sets) set da \(Clock.text(Double(seconds)))" }
        let reps = repsMin == repsMax ? "\(repsMin)" : "\(repsMin) a \(repsMax)"
        return "\(sets) set da \(reps)"
    }

    /// «Poi Lat machine».
    public static func then(_ exercise: String) -> String { "Poi \(exercise)" }

    /// Riga sotto il tempo del dock: «Poi Lat machine, 3 set da 8 a 12».
    public static func subtitle(exercise: String, detail: String) -> String {
        detail.isEmpty ? then(exercise) : "\(then(exercise)), \(detail)"
    }

    /// «Vai a Lat machine».
    public static func goTo(_ exercise: String) -> String { "Vai a \(exercise)" }
}
