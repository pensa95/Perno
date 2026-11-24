import Foundation

// MARK: - Unità e dischi

/// Unità con cui si leggono i pesi. I pesi si salvano sempre in chili: le libbre sono solo un
/// formato di visualizzazione (per questo lo storico «si converte» da solo).
public enum WeightUnit: String, CaseIterable, Sendable {
    case kilograms
    case pounds

    public static let kilogramsPerPound = 0.45359237

    /// «kg», «lb».
    public var symbol: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lb"
        }
    }

    /// «Chili», «Libbre».
    public var name: String {
        switch self {
        case .kilograms: return "Chili"
        case .pounds: return "Libbre"
        }
    }

    /// Da chili a questa unità.
    public func fromKilograms(_ kilograms: Double) -> Double {
        self == .kilograms ? kilograms : kilograms / Self.kilogramsPerPound
    }

    /// Da questa unità a chili.
    public func toKilograms(_ value: Double) -> Double {
        self == .kilograms ? value : value * Self.kilogramsPerPound
    }
}

/// Impostazioni «Unità e dischi» in uso. L'app le imposta all'avvio e quando cambiano;
/// i valori predefiniti sono chili e passo 2,5.
public enum Units {
    public static var unit: WeightUnit = .kilograms
    /// Passo dei dischi nell'unità in uso.
    public static var step: Double = PlateStep.standard

    /// Passi possibili: 1, 1,25, 2,5, 5.
    public static let steps: [Double] = [1, 1.25, 2.5, 5]

    /// Passo dei dischi in chili (per arrotondare i pesi salvati).
    public static var stepInKilograms: Double { unit.toKilograms(step) }

    /// Peso salvato (in chili) scritto nell'unità in uso: «62,5».
    public static func show(_ kilograms: Double) -> String {
        Weights.format((unit.fromKilograms(kilograms) * 100).rounded() / 100)
    }

    /// «Chili, passo 2,5» (voce «Unità e dischi» delle Impostazioni).
    public static func summary(unit: WeightUnit, step: Double) -> String {
        "\(unit.name), passo \(Weights.format(step))"
    }

    /// Esempio della tavola «Unità e dischi», nell'unità mostrata: da 62,5 il prossimo aumento
    /// («62,5 → 65») e l'avvicinamento al 75% arrotondato al passo («47,5»).
    public static func example(step: Double, base: Double = 62.5) -> (increase: String, approach: String) {
        let increase = "\(Weights.format(base)) → \(Weights.format(base + step))"
        let approach = Weights.format(Weights.round(base * 0.75, step: step))
        return (increase, approach)
    }
}

extension PlateStep {
    /// Passo dei dischi in uso, in chili (da «Unità e dischi»).
    public static var current: Double { Units.stepInKilograms }
}
