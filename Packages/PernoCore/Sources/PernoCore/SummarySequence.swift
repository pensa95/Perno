import Foundation

/// Riepilogo in sequenza (D7): prima la durata, poi i set, poi i kg, poi i record uno dopo l'altro, ognuno
/// quando finisce il precedente. Il «progresso» va da 0 al numero dei passi; ogni passo vale 1.
public enum SummarySequence {
    /// Secondi di ogni passo (0,5–0,6 s).
    public static let stepDuration: TimeInterval = 0.55
    /// Passi dei tre numeri: durata, set, kg.
    public static let numberSteps = 3

    /// Passi totali: i tre numeri e un passo per record.
    public static func steps(records: Int) -> Int {
        numberSteps + max(records, 0)
    }

    /// Durata di tutta la sequenza, in secondi.
    public static func duration(records: Int) -> TimeInterval {
        Double(steps(records: records)) * stepDuration
    }

    /// Quanto è avanzato il passo `step` (0 = durata, 1 = set, 2 = kg, 3… = record) al progresso dato:
    /// da 0 a 1, con uscita dolce (rallenta in fondo).
    public static func fraction(progress: Double, step: Int) -> Double {
        let linear = min(max(progress - Double(step), 0), 1)
        return 1 - (1 - linear) * (1 - linear)
    }
}
