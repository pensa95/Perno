import Foundation

/// Pesi: arrotondamento al passo dei dischi e formato italiano.
public enum Weights {
    /// Arrotonda `value` al multiplo più vicino di `step`; a metà strada arrotonda per eccesso.
    public static func round(_ value: Double, step: Double) -> Double {
        precondition(step > 0, "Il passo dei dischi deve essere positivo")
        let multiples = (value / step + 1e-9).rounded(.toNearestOrAwayFromZero)
        return multiples * step
    }

    /// «62,5», «60», «1,25»: decimali con la virgola, niente zeri inutili.
    public static func format(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }
}

/// Avvicinamenti: set leggeri in percentuale del peso di lavoro di oggi.
public enum Approach {
    /// 1 set → 60%; 2 set → 50/75%; 3 set → 40/60/80%. Altri valori: nessun avvicinamento.
    public static func percentages(count: Int) -> [Double] {
        switch count {
        case 1: return [0.60]
        case 2: return [0.50, 0.75]
        case 3: return [0.40, 0.60, 0.80]
        default: return []
        }
    }

    /// Pesi degli avvicinamenti, arrotondati al passo dei dischi.
    public static func weights(count: Int, workWeight: Double, step: Double) -> [Double] {
        percentages(count: count).map { Weights.round(workWeight * $0, step: step) }
    }
}
