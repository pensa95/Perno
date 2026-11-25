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
        /// Record a tempo (UI v5): durata più lunga in secondi; `nil` per i record a ripetizioni.
        public var seconds: Int?
        public var withWeight: Bool

        public init(exercise: String, lift: Lift, seconds: Int? = nil, withWeight: Bool = true) {
            self.exercise = exercise
            self.lift = lift
            self.seconds = seconds
            self.withWeight = withWeight
        }

        /// «Record su Lat machine».
        public var title: String { "Record su \(exercise)" }

        /// «55 × 10, massimale stimato 73 kg»; a tempo «10 × 0:55, durata più lunga».
        public var detail: String {
            if let seconds {
                return "\(TimedText.value(seconds: seconds, weight: withWeight ? lift.weight : nil)), durata più lunga"
            }
            let max = Int(Units.unit.fromKilograms(lift.estimatedMax).rounded())
            return "\(SessionText.weightReps(lift.weight, lift.reps)), massimale stimato \(max) \(Units.unit.symbol)"
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

    /// Tempo di una parte nella legenda, in minuti e secondi: «7:20», «0:45», «1:02:05».
    public static func partClock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return hours > 0 ? "\(hours):\(two(minutes)):\(two(secs))" : "\(minutes):\(two(secs))"
    }

    /// Tempo di una parte per VoiceOver: «7 minuti e 20 secondi», «45 secondi», «1 minuto».
    public static func spokenDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded())
        let minutes = total / 60
        let secs = total % 60
        let minText = minutes == 1 ? "1 minuto" : "\(minutes) minuti"
        let secText = secs == 1 ? "1 secondo" : "\(secs) secondi"
        if minutes == 0 { return secText }
        if secs == 0 { return minText }
        return "\(minText) e \(secText)"
    }

    /// Etichetta per VoiceOver: «Riscaldamento 7 minuti e 20 secondi, lavoro 12 minuti, …».
    public static func accessibilityLabel(_ breakdown: TimeBreakdown) -> String {
        TimePart.allCases.map { part -> String in
            let name = part == .warmUp ? part.label : part.label.lowercased()
            return "\(name) \(spokenDuration(seconds(part, in: breakdown)))"
        }
        .joined(separator: ", ")
    }
}
