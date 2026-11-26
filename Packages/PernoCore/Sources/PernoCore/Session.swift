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

/// Obiettivi di oggi di un esercizio (UI v6): set di lavoro, peso (in chili) e ripetizioni.
public struct TodayTargets: Equatable, Sendable {
    public var sets: Int
    public var weight: Double
    public var reps: Int

    public init(sets: Int, weight: Double, reps: Int) {
        self.sets = sets
        self.weight = weight
        self.reps = reps
    }

    /// In scaletta: «3 × 40 × 10»; a tempo «3 × 0:45» o, con il peso, «3 × 10 × 0:45».
    public func summary(seconds: Int? = nil, withWeight: Bool = true) -> String {
        if let seconds {
            let time = Clock.text(Double(seconds))
            return withWeight ? "\(sets) × \(Units.show(weight)) × \(time)" : "\(sets) × \(time)"
        }
        return "\(sets) × \(Units.show(weight)) × \(reps)"
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

    public init(exerciseIndex: Int, setIndex: Int, kind: SetKind, weight: Double, reps: Int,
                startedAt: Date, endedAt: Date) {
        self.exerciseIndex = exerciseIndex
        self.setIndex = setIndex
        self.kind = kind
        self.weight = weight
        self.reps = reps
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
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
    /// Sessione libera: finiti gli esercizi non finisce, torna al cambio esercizio («Scegli esercizi»).
    public private(set) var isOpenEnded = false

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
        guard currentSet != nil else { throw SessionError.invalidTransition }
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
        // Il prossimo set non ancora fatto (dopo «Elimina set» o «Completa» ci possono essere set
        // già fatti più avanti); finiti i set, il prossimo esercizio con set da fare.
        if let next = firstUndoneSet(of: exerciseIndex, after: setIndex) {
            setIndex = next
            phase = .rest(since: now)
        } else {
            moveToNextExercise(at: now)
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
            // Dopo l'ultimo set si salta agli esercizi con set da fare: si torna a quello del set.
            previousPosition = order[..<min(position, order.count)].lastIndex(of: last.exerciseIndex) ?? -1
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

// MARK: - Correggi set

extension SessionMachine {
    /// «Salva» in Correggi set: nuovi valori di un set fatto. Se cambia il peso di un set di lavoro,
    /// i set dopo, non ancora fatti, che avevano lo stesso obiettivo prendono il peso nuovo
    /// (così la prima volta, con l'obiettivo a 0, basta correggere il primo set).
    /// Restituisce gli indici dei set a cui è cambiato l'obiettivo.
    @discardableResult
    public mutating func correctSet(exercise: Int, set: Int, weight: Double, reps: Int,
                                    kind: SetKind) throws -> [Int] {
        guard let done = completedSets.firstIndex(where: { $0.exerciseIndex == exercise && $0.setIndex == set }) else {
            throw SessionError.invalidTransition
        }
        let oldWeight = completedSets[done].weight
        completedSets[done].weight = SetCorrection.clampWeight(weight)
        completedSets[done].reps = EntryLimits.clamp(reps, EntryLimits.reps)
        completedSets[done].kind = kind
        let newWeight = completedSets[done].weight

        guard kind != .approach, abs(newWeight - oldWeight) > 0.001 else { return [] }
        var changed: [Int] = []
        for index in exercises[exercise].sets.indices where index > set {
            let planned = exercises[exercise].sets[index]
            let isDone = completedSets.contains { $0.exerciseIndex == exercise && $0.setIndex == index }
            guard !isDone, planned.kind != .approach, abs(planned.weight - oldWeight) < 0.001 else { continue }
            exercises[exercise].sets[index].weight = newWeight
            changed.append(index)
        }
        return changed
    }

    /// «Elimina set»: il set torna non fatto (resta nella scheda di oggi, senza valori).
    public mutating func removeSet(exercise: Int, set: Int) throws {
        guard let done = completedSets.firstIndex(where: { $0.exerciseIndex == exercise && $0.setIndex == set }) else {
            throw SessionError.invalidTransition
        }
        completedSets.remove(at: done)
    }
}

/// Correggi set: limiti, passi e testi.
public enum SetCorrection {
    public static let weights: ClosedRange<Double> = 0...500

    public static func clampWeight(_ weight: Double) -> Double {
        min(max(weight, weights.lowerBound), weights.upperBound)
    }

    /// −/+ sul peso: un passo dei dischi, senza uscire dai limiti.
    /// Il conto si fa nell'unità in uso, così in libbre si resta sui multipli del passo.
    public static func stepWeight(_ weight: Double, by delta: Double) -> Double {
        let unit = Units.unit
        let shown = ((unit.fromKilograms(weight) + unit.fromKilograms(delta)) * 100).rounded() / 100
        return clampWeight(unit.toKilograms(shown))
    }

    /// Peso scritto con il tastierino: «62,5» o «62.5». `nil` se non è un numero.
    public static func parseWeight(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value.isFinite else { return nil }
        return clampWeight(Units.unit.toKilograms((value * 100).rounded() / 100))
    }

    /// Ripetizioni scritte con il tastierino. `nil` se non è un numero intero.
    public static func parseReps(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)) else { return nil }
        return EntryLimits.clamp(value, EntryLimits.reps)
    }

    /// Riga sotto «Altri dettagli»: «Set normale, ne avevi ancora 1».
    public static func details(kind: SetKind, reserve: Reserve?) -> String {
        let type: String
        switch kind {
        case .approach: type = "Avvicinamento"
        case .work: type = "Set normale"
        case .drop: type = "Drop set"
        case .failure: type = "Set a cedimento"
        }
        guard let reserve else { return type }
        return "\(type), ne avevi ancora \(reserve.label)"
    }

    /// «Chest press, fatto in 0:31».
    public static func subtitle(exercise: String, duration: TimeInterval?) -> String {
        guard let duration else { return exercise }
        return "\(exercise), fatto in \(SessionText.clock(duration))"
    }
}

// MARK: - Correggi un set non ancora fatto

extension SessionMachine {
    /// Correggi set su un set da fare (anche quello di adesso): cambia l'obiettivo.
    /// Se cambia il peso di un set di lavoro, i set dopo non ancora fatti con lo stesso obiettivo
    /// prendono il peso nuovo; se è il primo set di lavoro, anche gli avvicinamenti non ancora
    /// fatti si ricalcolano in percentuale (solo quelli che seguivano ancora la regola).
    /// Restituisce gli indici dei set a cui è cambiato l'obiettivo.
    @discardableResult
    public mutating func retargetSet(exercise: Int, set: Int, weight: Double, reps: Int,
                                     kind: SetKind, step: Double) throws -> [Int] {
        guard exercises.indices.contains(exercise), exercises[exercise].sets.indices.contains(set),
              !isDone(exercise: exercise, set: set) else {
            throw SessionError.invalidTransition
        }
        let oldWeight = exercises[exercise].sets[set].weight
        let newWeight = SetCorrection.clampWeight(weight)
        exercises[exercise].sets[set] = PlannedSet(kind: kind, weight: newWeight,
                                                   reps: EntryLimits.clamp(reps, EntryLimits.reps))
        var changed: Set<Int> = [set]
        guard kind != .approach, abs(newWeight - oldWeight) > 0.001 else { return changed.sorted() }

        let sets = exercises[exercise].sets
        for index in sets.indices where index > set {
            guard !isDone(exercise: exercise, set: index), sets[index].kind != .approach,
                  abs(sets[index].weight - oldWeight) < 0.001 else { continue }
            exercises[exercise].sets[index].weight = newWeight
            changed.insert(index)
        }

        let firstWork = sets.firstIndex { $0.kind != .approach }
        if firstWork == set {
            let approachIndices = sets.indices.filter { sets[$0].kind == .approach }
            let before = Approach.weights(count: approachIndices.count, workWeight: oldWeight, step: step)
            let after = Approach.weights(count: approachIndices.count, workWeight: newWeight, step: step)
            for (number, index) in approachIndices.enumerated() where number < before.count {
                guard !isDone(exercise: exercise, set: index),
                      abs(sets[index].weight - before[number]) < 0.001 else { continue }
                exercises[exercise].sets[index].weight = after[number]
                changed.insert(index)
            }
        }
        return changed.sorted()
    }

    public func isDone(exercise: Int, set: Int) -> Bool {
        completedSets.contains { $0.exerciseIndex == exercise && $0.setIndex == set }
    }
}

extension SetCorrection {
    /// Sottotitolo di Correggi set su un set da fare: «Chest press, obiettivo».
    public static func targetSubtitle(exercise: String) -> String {
        "\(exercise), obiettivo"
    }
}

// MARK: - Scaletta

extension SessionMachine {
    /// Nuovo ordine degli esercizi dopo quello di adesso (stessi esercizi, ordine diverso).
    public mutating func reorderUpcoming(_ tail: [Int]) throws {
        guard position < order.count else { throw SessionError.invalidTransition }
        let current = Array(order[(position + 1)...])
        guard tail.sorted() == current.sorted() else { throw SessionError.invalidTransition }
        order = Array(order[...position]) + tail
    }
}

// MARK: - Ripresa dopo un'interruzione

extension SessionMachine {
    /// Ripresa: riparte dal set dopo l'ultimo «Set fatto». Se l'esercizio ha ancora set, il recupero
    /// riparte da adesso; altrimenti cambio esercizio (da adesso) sul primo esercizio dopo con set
    /// da fare. Il riscaldamento non si ripete.
    public init(resuming exercises: [PlannedExercise], completed: [CompletedSet], pauses: [Pause],
                openEnded: Bool = false, at now: Date) {
        self.init(exercises: exercises, warmUp: false, at: now)
        isOpenEnded = openEnded
        if openEnded && exercises.isEmpty {
            completedSets = []
            self.pauses = pauses
            phase = .changeover(since: now)
            return
        }
        let sorted = completed.sorted { $0.endedAt < $1.endedAt }
        completedSets = sorted
        self.pauses = pauses
        guard !exercises.isEmpty else { return }

        func undone(_ exercise: Int) -> [Int] {
            exercises[exercise].sets.indices.filter { index in
                !sorted.contains { $0.exerciseIndex == exercise && $0.setIndex == index }
            }
        }

        var start = 0
        if let last = sorted.last, let lastPosition = order.firstIndex(of: last.exerciseIndex) {
            if let next = undone(last.exerciseIndex).first(where: { $0 > last.setIndex }) {
                position = lastPosition
                setIndex = next
                phase = .rest(since: now)
                return
            }
            start = lastPosition + 1
        }
        for candidate in start..<order.count {
            if let first = undone(order[candidate]).first {
                position = candidate
                setIndex = first
                phase = .changeover(since: now)
                return
            }
        }
        position = order.count
        setIndex = 0
        phase = openEnded ? .changeover(since: now) : .finished
    }
}

// MARK: - Sessione libera

extension SessionMachine {
    /// Sessione libera: si apre con il riscaldamento (se attivo) e senza esercizi; si aggiungono strada facendo.
    public init(openEndedAt now: Date, warmUp: Bool) {
        self.init(exercises: [], warmUp: false, at: now)
        isOpenEnded = true
        phase = warmUp ? .warmUp(since: now) : .changeover(since: now)
    }

    /// «Aggiungi esercizi» (solo per oggi): in fondo all'ordine di oggi. Se non c'era niente da fare,
    /// il primo aggiunto diventa l'esercizio di adesso.
    public mutating func appendExercises(_ added: [PlannedExercise], at now: Date) {
        guard !added.isEmpty else { return }
        let first = exercises.count
        exercises.append(contentsOf: added)
        order.append(contentsOf: first..<exercises.count)
        if phase == .finished {
            phase = .changeover(since: now)
        }
    }
}

// MARK: - Menu «…» dell'esercizio

extension SessionMachine {
    /// «+ set»: un set di lavoro in più in fondo all'esercizio, con l'obiettivo dell'ultimo set di
    /// lavoro (o, senza set di lavoro, dell'ultimo set). Restituisce l'indice del set nuovo.
    /// Set da fare che si può togliere scorrendo la piastra (UI v6, tavola 9): non fatto, non quello in corso
    /// (3-2-1 o set in corso), e l'esercizio deve tenere almeno un set.
    public func canDeleteUndoneSet(exercise: Int, set: Int) -> Bool {
        guard exercises.indices.contains(exercise), exercises[exercise].sets.indices.contains(set),
              exercises[exercise].sets.count > 1, !isDone(exercise: exercise, set: set) else { return false }
        if exercise == currentExerciseIndex, set == setIndex {
            switch phase {
            case .countdown, .inSet: return false
            default: break
            }
        }
        return true
    }

    /// «Rimuovi» su una piastra da fare: il set sparisce dall'esercizio, gli indici dei set dopo scalano.
    /// Se era il prossimo set dell'esercizio di adesso tocca al set dopo; se non ce ne sono più, si passa al
    /// cambio esercizio del successivo (il tempo del cambio parte dalla fine del recupero in corso, cioè
    /// dall'ultimo «Set fatto»).
    public mutating func deleteUndoneSet(exercise: Int, set: Int, at now: Date) throws {
        guard canDeleteUndoneSet(exercise: exercise, set: set) else { throw SessionError.invalidTransition }
        exercises[exercise].sets.remove(at: set)
        for index in completedSets.indices
        where completedSets[index].exerciseIndex == exercise && completedSets[index].setIndex > set {
            completedSets[index].setIndex -= 1
        }
        guard exercise == currentExerciseIndex else { return }
        if setIndex > set {
            setIndex -= 1
        } else if setIndex == set {
            if let next = firstUndoneSet(of: exercise, after: set - 1) {
                setIndex = next
            } else {
                switch phase {
                case let .rest(since), let .changeover(since):
                    moveToNextExercise(at: since)
                default:
                    moveToNextExercise(at: now)
                }
            }
        }
    }

    /// Obiettivi di oggi di un esercizio (UI v6, tavola 11): set di lavoro, peso e ripetizioni del primo set
    /// di lavoro. `nil` se l'esercizio non ha set di lavoro.
    public func todayTargets(exercise: Int) -> TodayTargets? {
        guard exercises.indices.contains(exercise) else { return nil }
        let work = exercises[exercise].sets.filter { $0.kind != .approach }
        guard let first = work.first else { return nil }
        return TodayTargets(sets: work.count, weight: first.weight, reps: first.reps)
    }

    /// Gli obiettivi di oggi si cambiano solo su un esercizio non ancora cominciato (nessun set fatto e,
    /// se è quello di adesso, prima del primo «Inizia»).
    public func canSetTodayTargets(exercise: Int) -> Bool {
        guard exercises.indices.contains(exercise),
              !exercises[exercise].sets.indices.contains(where: { isDone(exercise: exercise, set: $0) }) else {
            return false
        }
        if exercise == currentExerciseIndex {
            switch phase {
            case .changeover, .warmUp: return true
            default: return false
            }
        }
        return true
    }

    /// «Obiettivi di oggi» → «Salva»: valgono per tutti i set di lavoro di oggi (stesso peso e ripetizioni,
    /// `sets` set); gli avvicinamenti restano quanti erano, con il peso ricalcolato in percentuale del peso
    /// nuovo. Solo per questa sessione: la scheda non cambia.
    public mutating func setTodayTargets(exercise: Int, targets: TodayTargets, step: Double) throws {
        guard canSetTodayTargets(exercise: exercise) else { throw SessionError.invalidTransition }
        let approaches = exercises[exercise].sets.filter { $0.kind == .approach }
        let weights = Approach.weights(count: approaches.count, workWeight: targets.weight, step: step)
        let warmUps = zip(approaches, weights).map { PlannedSet(kind: .approach, weight: $1, reps: $0.reps) }
        let work = (0..<max(targets.sets, 1)).map { _ in
            PlannedSet(kind: .work, weight: targets.weight, reps: targets.reps)
        }
        exercises[exercise].sets = warmUps + work
        if exercise == currentExerciseIndex { setIndex = 0 }
    }

    /// «Sostituisci» si può usare su questo esercizio: ha set da fare e non c'è un suo set in corso.
    public func canReplace(exercise: Int) -> Bool {
        guard exercises.indices.contains(exercise), firstUndoneSet(of: exercise) != nil else { return false }
        if exercise == currentExerciseIndex {
            switch phase {
            case .countdown, .inSet, .finished: return false
            default: break
            }
        }
        return true
    }

    /// «Sostituisci» (UI v6, tavola 12), solo per oggi: i set fatti restano sull'esercizio vecchio, quelli da
    /// fare spariscono; `planned` (gli stessi set, con gli obiettivi dell'esercizio nuovo) entra subito dopo
    /// il vecchio nell'ordine di oggi (se il vecchio non ha set fatti esce dall'ordine). Se il vecchio era quello di adesso, il nuovo diventa quello di adesso,
    /// nel cambio esercizio (dal recupero in corso, il tempo del cambio parte dall'ultimo «Set fatto»).
    /// Restituisce l'indice dell'esercizio nuovo.
    @discardableResult
    public mutating func replaceExercise(_ old: Int, with planned: PlannedExercise, at now: Date) throws -> Int {
        guard canReplace(exercise: old), !planned.sets.isEmpty else { throw SessionError.invalidTransition }
        let wasCurrent = old == currentExerciseIndex
        let kept = exercises[old].sets.indices.filter { isDone(exercise: old, set: $0) }
        var newIndexOf: [Int: Int] = [:]
        for (new, previous) in kept.enumerated() { newIndexOf[previous] = new }
        exercises[old].sets = kept.map { exercises[old].sets[$0] }
        for index in completedSets.indices where completedSets[index].exerciseIndex == old {
            completedSets[index].setIndex = newIndexOf[completedSets[index].setIndex] ?? completedSets[index].setIndex
        }
        exercises.append(planned)
        let added = exercises.count - 1
        let slot = order.firstIndex(of: old).map { $0 + 1 } ?? order.count
        order.insert(added, at: slot)
        if wasCurrent {
            position = slot
            setIndex = 0
            if case let .rest(since) = phase { phase = .changeover(since: since) }
        } else if slot <= position {
            position += 1
        }
        // Sostituito prima di fare set: il vecchio resta vuoto e sparisce dall'ordine di oggi.
        if kept.isEmpty, let previous = order.firstIndex(of: old) {
            order.remove(at: previous)
            if previous < position { position -= 1 }
        }
        return added
    }

    @discardableResult
    public mutating func addSet(toExercise exercise: Int) throws -> Int {
        guard exercises.indices.contains(exercise) else { throw SessionError.invalidTransition }
        let sets = exercises[exercise].sets
        let model = sets.last { $0.kind != .approach } ?? sets.last
        exercises[exercise].sets.append(PlannedSet(kind: .work, weight: model?.weight ?? 0,
                                                   reps: model?.reps ?? FreeSessionText.addedRepsMin))
        return exercises[exercise].sets.count - 1
    }
}

// MARK: - «Completa» dal riepilogo

extension SessionMachine {
    /// Primo set non fatto di un esercizio dopo `index` (escluso); `nil` se sono tutti fatti.
    public func firstUndoneSet(of exercise: Int, after index: Int = -1) -> Int? {
        guard exercises.indices.contains(exercise) else { return nil }
        return exercises[exercise].sets.indices.first { $0 > index && !isDone(exercise: exercise, set: $0) }
    }

    /// «Completa» nel riepilogo: l'esercizio diventa quello di adesso, dal primo set non fatto, con
    /// il cambio esercizio da adesso. Gli altri esercizi con set da fare restano dopo, nello stesso
    /// ordine. Se l'esercizio è già quello di adesso, la sessione riprende da dove era.
    public mutating func complete(exercise: Int, at now: Date) throws {
        guard let first = firstUndoneSet(of: exercise) else { throw SessionError.invalidTransition }
        if exercise == currentExerciseIndex && phase != .finished { return }
        if let index = order.firstIndex(of: exercise) {
            order.remove(at: index)
            if index < position { position -= 1 }
        }
        position = min(position, order.count)
        order.insert(exercise, at: position)
        setIndex = first
        phase = .changeover(since: now)
    }

    /// Dopo l'ultimo set di un esercizio: il prossimo esercizio con set da fare (dal primo non fatto).
    mutating func moveToNextExercise(at now: Date) {
        position += 1
        while position < order.count, firstUndoneSet(of: order[position]) == nil {
            position += 1
        }
        if position < order.count, let first = firstUndoneSet(of: order[position]) {
            setIndex = first
            phase = .changeover(since: now)
        } else {
            setIndex = 0
            phase = isOpenEnded ? .changeover(since: now) : .finished
        }
    }
}

// MARK: - Esercizio tolto dalla scheda (UI v6, T12)

extension SessionMachine {
    /// Un esercizio tolto dalla scheda sparisce dalla sessione solo se non ha set fatti e non è in corso
    /// (3-2-1, set o recupero).
    public func canDrop(exercise: Int) -> Bool {
        guard exercises.indices.contains(exercise), order.contains(exercise),
              !exercises[exercise].sets.indices.contains(where: { isDone(exercise: exercise, set: $0) }) else {
            return false
        }
        if exercise == currentExerciseIndex {
            switch phase {
            case .changeover, .warmUp: return true
            default: return false
            }
        }
        return true
    }

    /// Toglie l'esercizio dall'ordine di oggi; se era quello di adesso, tocca al successivo con set da fare
    /// (nel cambio esercizio che era già in corso). Senza altri esercizi la sessione è finita.
    public mutating func drop(exercise: Int, at now: Date) throws {
        guard canDrop(exercise: exercise), let slot = order.firstIndex(of: exercise) else {
            throw SessionError.invalidTransition
        }
        let wasCurrent = exercise == currentExerciseIndex
        order.remove(at: slot)
        if slot < position {
            position -= 1
        } else if wasCurrent {
            while position < order.count, firstUndoneSet(of: order[position]) == nil {
                position += 1
            }
            if position < order.count, let first = firstUndoneSet(of: order[position]) {
                setIndex = first
            } else {
                setIndex = 0
                if !isOpenEnded, case .changeover = phase { phase = .finished }
            }
        }
    }
}
