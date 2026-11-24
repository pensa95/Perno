import Foundation

// MARK: - Riepilogo

/// Riepilogo di fine sessione: set non fatti, record, variazione dei kg e barra del tempo.
public enum SessionSummary {
    /// Un set fatto (peso in chili).
    public struct Lift: Equatable, Sendable {
        public var weight: Double
        public var reps: Int

        public init(weight: Double, reps: Int) {
            self.weight = weight
            self.reps = reps
        }

        /// Massimale stimato (formula di Epley); con una sola ripetizione è il peso stesso.
        public var estimatedMax: Double {
            reps <= 1 ? weight : weight * (1 + Double(reps) / 30)
        }
    }

    /// Record di un esercizio: il set di oggi con il massimale stimato più alto.
    public struct Record: Equatable, Sendable {
        public var exercise: String
        public var lift: Lift

        public init(exercise: String, lift: Lift) {
            self.exercise = exercise
            self.lift = lift
        }

        /// «Record su Lat machine».
        public var title: String { "Record su \(exercise)" }

        /// «55 × 10, massimale stimato 73 kg».
        public var detail: String {
            let max = Int(lift.estimatedMax.rounded())
            return "\(SessionText.weightReps(lift.weight, lift.reps)), massimale stimato \(max) kg"
        }
    }

    /// Record: il miglior set di oggi supera il massimale stimato di tutte le volte prima.
    /// Serve almeno una volta prima (la prima volta non è un record); set a 0 kg esclusi.
    public static func record(exercise: String, today: [Lift], previous: [Lift]) -> Record? {
        let valid = today.filter { $0.weight > 0 && $0.reps > 0 }
        let before = previous.filter { $0.weight > 0 && $0.reps > 0 }
        guard let best = valid.max(by: { $0.estimatedMax < $1.estimatedMax }),
              let previousBest = before.map(\.estimatedMax).max(),
              best.estimatedMax > previousBest + 0.001 else { return nil }
        return Record(exercise: exercise, lift: best)
    }

    /// «+2%» accanto ai kg, rispetto alla volta scorsa con la stessa scheda; `nil` senza confronto.
    public static func volumeChange(today: Double, previous: Double?) -> String? {
        guard let previous, previous > 0 else { return nil }
        let percent = Int(((today - previous) / previous * 100).rounded())
        if percent > 0 { return "+\(percent)%" }
        if percent < 0 { return "−\(-percent)%" }
        return "0%"
    }

    /// Esercizio con set di lavoro non fatti: «Croci ai cavi, 1 set non fatto».
    public static func undoneTitle(exercise: String, count: Int) -> String {
        count == 1 ? "\(exercise), 1 set non fatto" : "\(exercise), \(count) set non fatti"
    }

    /// «Puoi farlo adesso o lasciarlo» (al plurale con più set).
    public static func undoneSubtitle(count: Int) -> String {
        count == 1 ? "Puoi farlo adesso o lasciarlo" : "Puoi farli adesso o lasciarli"
    }

    // MARK: Barra del tempo

    /// Parti della barra del tempo, nell'ordine della legenda.
    public enum TimePart: CaseIterable, Sendable {
        case warmUp
        case work
        case rest
        case changeover

        public var label: String {
            switch self {
            case .warmUp: return "Riscaldamento"
            case .work: return "Lavoro"
            case .rest: return "Recupero"
            case .changeover: return "Cambi"
            }
        }
    }

    public static func seconds(_ part: TimePart, in breakdown: TimeBreakdown) -> TimeInterval {
        switch part {
        case .warmUp: return max(0, breakdown.warmUp)
        case .work: return max(0, breakdown.work)
        case .rest: return max(0, breakdown.rest)
        case .changeover: return max(0, breakdown.changeover)
        }
    }

    /// Frazioni della barra (somma 1); vuoto se non c'è tempo misurato.
    public static func fractions(_ breakdown: TimeBreakdown) -> [TimePart: Double] {
        let total = TimePart.allCases.reduce(0) { $0 + seconds($1, in: breakdown) }
        guard total > 0 else { return [:] }
        var result: [TimePart: Double] = [:]
        for part in TimePart.allCases {
            result[part] = seconds(part, in: breakdown) / total
        }
        return result
    }

    /// Minuti arrotondati: «7 min».
    public static func minutes(_ seconds: TimeInterval) -> String {
        "\(Int((max(0, seconds) / 60).rounded())) min"
    }

    /// Etichetta per VoiceOver: «Riscaldamento 7, lavoro 12, recupero 29, cambi 10 minuti».
    public static func accessibilityLabel(_ breakdown: TimeBreakdown) -> String {
        let parts = TimePart.allCases.map { part -> String in
            let value = Int((seconds(part, in: breakdown) / 60).rounded())
            let name = part == .warmUp ? part.label : part.label.lowercased()
            return "\(name) \(value)"
        }
        return parts.joined(separator: ", ") + " minuti"
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
