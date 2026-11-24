import Foundation

extension Weekday {
    /// «Lunedì» … «Domenica» (1 = lunedì).
    public static func name(_ weekday: Int) -> String {
        let names = ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
        return names.indices.contains(weekday - 1) ? names[weekday - 1] : ""
    }
}

/// Riassunto di una scheda: «5 esercizi, circa 55 minuti».
public enum RoutineSummary {
    /// Esercizio della scheda, per la stima.
    public struct Entry: Equatable, Sendable {
        public var sets: Int
        public var approaches: Int
        /// Recupero fissato in secondi; `nil` = recupero abituale.
        public var fixedRest: Double?

        public init(sets: Int, approaches: Int = 0, fixedRest: Double? = nil) {
            self.sets = sets
            self.approaches = approaches
            self.fixedRest = fixedRest
        }
    }

    // Tempi della stima, finché non ci sono dati misurati.
    public static let workSet: Double = 60
    public static let approachSet: Double = 45
    public static let approachRest: Double = 60
    public static let defaultRest: Double = 120
    public static let changeover: Double = 90

    /// Durata stimata in secondi: set e recuperi di ogni esercizio, più i cambi tra esercizi.
    /// `usualRest` è il recupero abituale (se `nil`, 2 minuti).
    public static func estimatedDuration(_ entries: [Entry], usualRest: Double? = nil) -> Double {
        guard !entries.isEmpty else { return 0 }
        let perEntry = entries.reduce(0.0) { total, entry in
            let rest = entry.fixedRest ?? usualRest ?? defaultRest
            let work = Double(max(entry.sets, 0)) * (workSet + rest)
            let approaches = Double(max(entry.approaches, 0)) * (approachSet + approachRest)
            return total + work + approaches
        }
        return perEntry + Double(entries.count - 1) * changeover
    }

    /// Minuti arrotondati ai 5 più vicini (almeno 5).
    public static func estimatedMinutes(_ entries: [Entry], usualRest: Double? = nil) -> Int {
        let minutes = estimatedDuration(entries, usualRest: usualRest) / 60
        return max(5, Int((minutes / 5).rounded()) * 5)
    }

    /// «Nessun esercizio», «1 esercizio, circa 10 minuti», «5 esercizi, circa 45 minuti».
    public static func text(_ entries: [Entry], usualRest: Double? = nil) -> String {
        guard !entries.isEmpty else { return "Nessun esercizio" }
        let count = entries.count == 1 ? "1 esercizio" : "\(entries.count) esercizi"
        return "\(count), circa \(estimatedMinutes(entries, usualRest: usualRest)) minuti"
    }
}
