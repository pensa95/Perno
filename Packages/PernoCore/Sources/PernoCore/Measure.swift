import Foundation

// Esercizi a tempo (UI v5): nella scheda ogni esercizio si misura in ripetizioni o a tempo.

/// Come si misura un esercizio nella scheda: «Ripetizioni» o «Tempo». Salvato come valore grezzo.
public enum SetMeasure: String, CaseIterable, Codable, Sendable {
    case reps
    case time

    public var label: String {
        switch self {
        case .reps: return "Ripetizioni"
        case .time: return "Tempo"
        }
    }
}

/// Durata obiettivo dei set a tempo: da 5 s a 10 minuti, a passi di 5 s.
public enum DurationLimits {
    public static let range = 5...600
    public static let step = 5
    public static let standard = 45
    /// Progressione: quando si tiene la durata in tutti i set, la volta dopo +5 s.
    public static let progressionStep = 5

    public static func clamp(_ seconds: Int) -> Int {
        EntryLimits.clamp(seconds, range)
    }

    /// Un passo in su o in giù, allineato ai 5 s.
    public static func stepped(_ seconds: Int, by steps: Int) -> Int {
        let aligned = Int((Double(seconds) / Double(step)).rounded()) * step
        return clamp(aligned + steps * step)
    }
}

extension EntrySummary {
    /// Riassunto di un esercizio a tempo: «3 set da 0:45, con peso, recupero 2:00».
    public static func timed(sets: Int, seconds: Int, withWeight: Bool, fixedRest: Double?) -> String {
        var parts = ["\(sets) set da \(Clock.text(Double(seconds)))"]
        if withWeight { parts.append("con peso") }
        if let fixedRest { parts.append("recupero \(Clock.text(fixedRest))") }
        return parts.joined(separator: ", ")
    }

    /// Riassunto secondo la misura dell'esercizio.
    public static func text(measure: SetMeasure, sets: Int, repsMin: Int, repsMax: Int, approaches: Int,
                            seconds: Int, withWeight: Bool, fixedRest: Double?) -> String {
        switch measure {
        case .reps:
            return text(sets: sets, repsMin: repsMin, repsMax: repsMax, approaches: approaches, fixedRest: fixedRest)
        case .time:
            return timed(sets: sets, seconds: seconds, withWeight: withWeight, fixedRest: fixedRest)
        }
    }
}

extension EntryHints {
    /// «Quando tieni 0:45 in tutti i set, la volta dopo l'app propone +5 s.»
    public static func timedProgression(seconds: Int) -> String {
        "Quando tieni \(Clock.text(Double(seconds))) in tutti i set, la volta dopo l'app propone +\(DurationLimits.progressionStep) s."
    }

    /// Sotto la spunta «Con peso».
    public static let withWeight = "Il peso si sceglie in sessione, come per gli altri esercizi"
}
