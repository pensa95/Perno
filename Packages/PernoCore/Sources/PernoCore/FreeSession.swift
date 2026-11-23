import Foundation

/// Testi della sessione libera e di «Aggiungi esercizi».
public enum FreeSessionText {
    /// «Riscaldamento fatto, 6 minuti»; `nil` se il riscaldamento non c'è stato.
    public static func warmUpDone(_ seconds: TimeInterval?) -> String? {
        guard let seconds else { return nil }
        let minutes = max(0, Int((seconds / 60).rounded()))
        return "Riscaldamento fatto, \(minutes == 1 ? "1 minuto" : "\(minutes) minuti")"
    }

    /// «Primo esercizio» se non ce n'è ancora uno, altrimenti «Prossimo esercizio».
    public static func title(exercisesSoFar: Int) -> String {
        exercisesSoFar == 0 ? "Primo esercizio" : "Prossimo esercizio"
    }

    /// «Ultima volta 120 × 10» (usati di recente).
    public static func lastTime(_ last: (weight: Double, reps: Int)?) -> String {
        guard let last else { return "Mai fatto" }
        return "Ultima volta \(SessionText.weightReps(last.weight, last.reps))"
    }

    /// «Macchina, ultima volta 120 × 10» o «Macchina, mai fatto» (Aggiungi esercizi).
    public static func librarySubtitle(equipment: Equipment, last: (weight: Double, reps: Int)?) -> String {
        guard let last else { return "\(equipment.label), mai fatto" }
        return "\(equipment.label), ultima volta \(SessionText.weightReps(last.weight, last.reps))"
    }

    /// «Aggiungi 2 esercizi», «Aggiungi 1 esercizio», senza scelta «Aggiungi esercizi».
    public static func addButton(_ count: Int) -> String {
        switch count {
        case 0: return "Aggiungi esercizi"
        case 1: return "Aggiungi 1 esercizio"
        default: return "Aggiungi \(count) esercizi"
        }
    }

    /// Set più pesante dell'ultima volta (a parità di peso, quello con più ripetizioni).
    public static func best(_ sets: [(weight: Double, reps: Int)]) -> (weight: Double, reps: Int)? {
        sets.max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }

    /// Esercizio aggiunto solo per oggi: 3 set da 8 a 12, nessun avvicinamento.
    public static let addedSets = 3
    public static let addedRepsMin = 8
    public static let addedRepsMax = 12
}
