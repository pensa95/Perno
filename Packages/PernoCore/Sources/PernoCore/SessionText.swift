import Foundation

/// Testi della schermata della sessione (piastre, dock, 3-2-1).
public enum SessionText {
    /// Cronometro: «0:24», «11:02», «1:05:20».
    public static func clock(_ seconds: TimeInterval) -> String {
        HomeText.duration(floor(max(0, seconds)))
    }

    /// Numero di ogni set dentro il suo tipo: avvicinamenti «Avv. 1, 2…», set di lavoro «Set 1, 2…».
    public static func numbers(_ kinds: [SetKind]) -> [Int] {
        var approaches = 0
        var others = 0
        return kinds.map { kind in
            if kind == .approach {
                approaches += 1
                return approaches
            }
            others += 1
            return others
        }
    }

    /// «Avv. 1» o «Set 1» (piastre).
    public static func shortName(_ kind: SetKind, _ number: Int) -> String {
        kind == .approach ? "Avv. \(number)" : "Set \(number)"
    }

    /// «avvicinamento 1» o «set 1» (pulsanti e dock).
    private static func longName(_ kind: SetKind, _ number: Int) -> String {
        kind == .approach ? "avvicinamento \(number)" : "set \(number)"
    }

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    /// «Inizia avvicinamento 1», «Inizia set 2».
    public static func startTitle(_ kind: SetKind, _ number: Int) -> String {
        "Inizia \(longName(kind, number))"
    }

    /// «Set 1 fatto», «Avvicinamento 1 fatto».
    public static func doneTitle(_ kind: SetKind, _ number: Int) -> String {
        capitalized(longName(kind, number)) + " fatto"
    }

    /// «Set 1 in corso» (etichetta del dock).
    public static func inProgress(_ kind: SetKind, _ number: Int) -> String {
        capitalized(longName(kind, number)) + " in corso"
    }

    /// «Set 1 tra» (sopra il numero del 3-2-1).
    public static func countdownTitle(_ kind: SetKind, _ number: Int) -> String {
        capitalized(longName(kind, number)) + " tra"
    }

    /// «62,5 × 10».
    public static func weightReps(_ weight: Double, _ reps: Int) -> String {
        "\(Weights.format(weight)) × \(reps)"
    }

    /// «+2,5 kg» rispetto alla volta prima; `nil` se il peso non cambia.
    public static func delta(today: Double, before: Double) -> String? {
        let difference = today - before
        guard abs(difference) > 0.001 else { return nil }
        return (difference > 0 ? "+" : "−") + Weights.format(abs(difference)) + " kg"
    }

    /// «Esercizio 1 di 5, da 8 a 12 ripetizioni».
    public static func exerciseHeader(position: Int, count: Int, repsMin: Int, repsMax: Int) -> String {
        let reps = repsMin == repsMax ? "\(repsMin) ripetizioni" : "da \(repsMin) a \(repsMax) ripetizioni"
        return "Esercizio \(position) di \(count), \(reps)"
    }

    /// «Recupero, di solito 2:10»; senza dati solo «Recupero».
    public static func restLabel(usual: TimeInterval?) -> String {
        guard let usual else { return "Recupero" }
        return "Recupero, di solito \(clock(usual.rounded()))"
    }

    /// «50%» dell'avvicinamento `number` (1…) su `count` avvicinamenti.
    public static func approachPercent(number: Int, count: Int) -> String? {
        let percentages = Approach.percentages(count: count)
        guard number >= 1, number <= percentages.count else { return nil }
        return "\(Int((percentages[number - 1] * 100).rounded()))%"
    }

    /// Numero da mostrare nel 3-2-1 dopo `elapsed` secondi (3, 2, 1).
    public static func countdownValue(elapsed: TimeInterval, total: Int) -> Int {
        min(total, max(1, total - Int(floor(max(0, elapsed)))))
    }
}
