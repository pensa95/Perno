import Foundation

// MARK: - Piano della sessione

/// Tipo di set. Il valore grezzo è quello salvato: non cambiarlo.
public enum SetKind: String, CaseIterable, Codable, Sendable {
    case approach
    case work
    case drop
    case failure
}

public struct PlannedSet: Equatable, Sendable {
    public var kind: SetKind
    public var weight: Double
    public var reps: Int

    public init(kind: SetKind, weight: Double, reps: Int) {
        self.kind = kind
        self.weight = weight
        self.reps = reps
    }
}

public struct PlannedExercise: Equatable, Sendable {
    public var name: String
    public var sets: [PlannedSet]

    public init(name: String, sets: [PlannedSet]) {
        self.name = name
        self.sets = sets
    }
}

// MARK: - Registro

public struct CompletedSet: Equatable, Sendable {
    public var exerciseIndex: Int
    public var setIndex: Int
    public var kind: SetKind
    public var weight: Double
    public var reps: Int
    /// Fine del 3-2-1.
    public var startedAt: Date
    /// «Set fatto».
    public var endedAt: Date

    public var duration: TimeInterval { endedAt.timeIntervalSince(startedAt) }
}

public enum PauseKind: String, Codable, Sendable {
    case warmUp
    case rest
    case changeover
}

public struct Pause: Equatable, Sendable {
    public var kind: PauseKind
    /// Esercizio a cui appartiene la pausa (per il recupero: quello del set appena fatto).
    public var exerciseIndex: Int?
    /// Vero se il recupero segue un avvicinamento: è registrato ma non entra nella media.
    public var afterApproach: Bool
    public var start: Date
    public var end: Date

    public init(kind: PauseKind, exerciseIndex: Int?, afterApproach: Bool, start: Date, end: Date) {
        self.kind = kind
        self.exerciseIndex = exerciseIndex
        self.afterApproach = afterApproach
        self.start = start
        self.end = end
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

// MARK: - Macchina a stati

/// Fasi del dock: riscaldamento (arancio), cambio esercizio (grafite), 3-2-1,
/// set in corso (chiaro), recupero (blu). Non esiste lo stato «tocca a te».
public enum SessionPhase: Equatable, Sendable {
    case warmUp(since: Date)
    case changeover(since: Date)
    case countdown(since: Date, pauseStart: Date, pauseKind: PauseKind)
    case inSet(since: Date)
    case rest(since: Date)
    case finished
}

public enum SessionError: Error, Equatable {
    case invalidTransition
}

public struct SessionMachine: Sendable {
    public private(set) var exercises: [PlannedExercise]
    /// Ordine di oggi (indici in `exercises`); «Rimanda» lo cambia, la scheda no.
    public private(set) var order: [Int]
    /// Posizione in `order` dell'esercizio corrente.
    public private(set) var position: Int = 0
    /// Prossimo set da fare dell'esercizio corrente.
    public private(set) var setIndex: Int = 0
    public private(set) var phase: SessionPhase
    public private(set) var completedSets: [CompletedSet] = []
    public private(set) var pauses: [Pause] = []

    public init(exercises: [PlannedExercise], warmUp: Bool, at now: Date) {
        self.exercises = exercises
        self.order = Array(exercises.indices)
        if exercises.isEmpty {
            self.phase = .finished
        } else {
            self.phase = warmUp ? .warmUp(since: now) : .changeover(since: now)
        }
    }

    public var currentExerciseIndex: Int? {
        position < order.count ? order[position] : nil
    }

    public var currentSet: PlannedSet? {
        guard let index = currentExerciseIndex else { return nil }
        let sets = exercises[index].sets
        return setIndex < sets.count ? sets[setIndex] : nil
    }

    /// «Riscaldamento fatto» oppure «Salta»: in entrambi i casi il tempo è registrato.
    public mutating func endWarmUp(at now: Date) throws {
        guard case let .warmUp(since) = phase else { throw SessionError.invalidTransition }
        pauses.append(Pause(kind: .warmUp, exerciseIndex: nil, afterApproach: false, start: since, end: now))
        phase = .changeover(since: now)
    }

    /// «Inizia set N» (o «Inizia avvicinamento N»): chiude la pausa e parte il 3-2-1.
    public mutating func start(at now: Date) throws {
        switch phase {
        case let .changeover(since):
            phase = .countdown(since: now, pauseStart: since, pauseKind: .changeover)
        case let .rest(since):
            phase = .countdown(since: now, pauseStart: since, pauseKind: .rest)
        default:
            throw SessionError.invalidTransition
        }
    }

    /// Fine del 3-2-1: registra la pausa (3-2-1 escluso) e fa partire il set.
    public mutating func countdownFinished(at now: Date) throws {
        guard case let .countdown(since, pauseStart, pauseKind) = phase else {
            throw SessionError.invalidTransition
        }
        let previous = completedSets.last
        let afterApproach = pauseKind == .rest && previous?.kind == .approach
        let exerciseIndex = pauseKind == .rest ? previous?.exerciseIndex : currentExerciseIndex
        pauses.append(Pause(kind: pauseKind, exerciseIndex: exerciseIndex, afterApproach: afterApproach,
                            start: pauseStart, end: since))
        phase = .inSet(since: now)
    }

    /// «Set N fatto»: registra il set con i valori dati (di default l'obiettivo) e avanza.
    public mutating func setDone(at now: Date, weight: Double? = nil, reps: Int? = nil) throws {
        guard case let .inSet(since) = phase,
              let exerciseIndex = currentExerciseIndex,
              let planned = currentSet else {
            throw SessionError.invalidTransition
        }
        completedSets.append(CompletedSet(
            exerciseIndex: exerciseIndex,
            setIndex: setIndex,
            kind: planned.kind,
            weight: weight ?? planned.weight,
            reps: reps ?? planned.reps,
            startedAt: since,
            endedAt: now
        ))
        setIndex += 1
        if setIndex < exercises[exerciseIndex].sets.count {
            phase = .rest(since: now)
        } else {
            position += 1
            setIndex = 0
            phase = position < order.count ? .changeover(since: now) : .finished
        }
    }

    /// «Rimanda»: durante il cambio esercizio, l'esercizio corrente va in fondo all'ordine di oggi.
    public mutating func postponeCurrent() throws {
        guard case .changeover = phase, setIndex == 0, position < order.count - 1 else {
            throw SessionError.invalidTransition
        }
        let postponed = order.remove(at: position)
        order.append(postponed)
    }
}

// MARK: - Tempi

public struct TimeBreakdown: Equatable, Sendable {
    public var warmUp: TimeInterval
    public var work: TimeInterval
    public var rest: TimeInterval
    public var changeover: TimeInterval
}

public enum SessionStats {
    /// Riscaldamento, lavoro, recupero e cambi per la barra del tempo del riepilogo.
    public static func breakdown(sets: [CompletedSet], pauses: [Pause]) -> TimeBreakdown {
        func total(_ kind: PauseKind) -> TimeInterval {
            pauses.filter { $0.kind == kind }.reduce(0) { $0 + $1.duration }
        }
        return TimeBreakdown(
            warmUp: total(.warmUp),
            work: sets.reduce(0) { $0 + $1.duration },
            rest: total(.rest),
            changeover: total(.changeover)
        )
    }

    /// Recupero abituale: media degli ultimi `lastN` recuperi dei set di lavoro
    /// (esclusi i recuperi dopo un avvicinamento e i cambi esercizio). `nil` se non ci sono dati.
    public static func usualRest(_ pauses: [Pause], lastN: Int = 20) -> TimeInterval? {
        let rests = pauses.filter { $0.kind == .rest && !$0.afterApproach }.suffix(lastN)
        guard !rests.isEmpty else { return nil }
        return rests.reduce(0) { $0 + $1.duration } / Double(rests.count)
    }
}

// MARK: - Annulla del 3-2-1

extension SessionMachine {
    /// «Annulla» durante il 3-2-1: si torna alla pausa di prima, che continua a contare dal suo inizio.
    public mutating func cancelCountdown() throws {
        guard case let .countdown(_, pauseStart, pauseKind) = phase else {
            throw SessionError.invalidTransition
        }
        switch pauseKind {
        case .rest: phase = .rest(since: pauseStart)
        case .changeover: phase = .changeover(since: pauseStart)
        case .warmUp: phase = .warmUp(since: pauseStart)
        }
    }

    /// «Concludi»: la sessione finisce dove si trova; i set non fatti restano non fatti.
    public mutating func finish() {
        phase = .finished
    }
}

// MARK: - Avviso dopo «Set fatto»

extension SessionMachine {
    /// Ripetizioni dell'ultimo set fatto (−/+ nell'avviso), nei limiti delle ripetizioni.
    public mutating func correctLastSet(reps: Int) throws {
        guard !completedSets.isEmpty else { throw SessionError.invalidTransition }
        completedSets[completedSets.count - 1].reps = EntryLimits.clamp(reps, EntryLimits.reps)
    }

    /// «Annulla» nell'avviso: toglie l'ultimo set fatto e torna a quel set in corso, con il suo
    /// cronometro di prima. Vale solo finché non si è ripartiti (recupero, cambio esercizio o fine).
    public mutating func undoLastSet() throws {
        guard let last = completedSets.last else { throw SessionError.invalidTransition }
        let previousPosition: Int
        switch phase {
        case .rest:
            previousPosition = position
        case .changeover, .finished:
            previousPosition = position - 1
        default:
            throw SessionError.invalidTransition
        }
        guard previousPosition >= 0, previousPosition < order.count,
              order[previousPosition] == last.exerciseIndex else {
            throw SessionError.invalidTransition
        }
        completedSets.removeLast()
        position = previousPosition
        setIndex = last.setIndex
        phase = .inSet(since: last.startedAt)
    }
}
