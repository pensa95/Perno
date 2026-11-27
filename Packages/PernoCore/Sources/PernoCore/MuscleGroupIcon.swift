import Foundation

/// Icone dei gruppi muscolari (D8, tracciati approvati il 27/11): omino con la zona piena su una griglia
/// 48 × 48, solo riempimenti. La sagoma è fatta da tutte le zone della vista tranne quelle del gruppo; il
/// gruppo è in pieno. I tracciati sono SVG (solo M, L, H, V, C, Z assoluti); li disegna `IconaGruppo`.
public enum MuscleGroupIcon {
    /// Lato della griglia dei tracciati.
    public static let grid: Double = 48

    public enum View: Sendable { case front, back }

    /// Zone del corpo, per nome, in SVG.
    public static let zones: [String: String] = [
        "testa": "M 24.00 1.20 C 25.63 1.20 26.92 2.61 26.92 4.35 C 26.92 6.10 25.63 7.51 24.00 7.51 C 22.37 7.51 21.08 6.10 21.08 4.35 C 21.08 2.61 22.37 1.20 24.00 1.20 Z",
        "collo": "M 22.71 7.34 H 25.29 V 9.00 H 22.71 Z",
        "deltoidi": "M 16.60 9.50 C 14.37 9.58 12.73 10.74 12.30 12.74 L 12.13 15.31 C 13.25 15.14 14.28 14.48 15.06 13.48 C 15.40 11.99 15.83 10.58 16.60 9.50 Z M 31.40 9.50 C 33.63 9.58 35.27 10.74 35.70 12.74 L 35.87 15.31 C 34.75 15.14 33.72 14.48 32.94 13.48 C 32.60 11.99 32.17 10.58 31.40 9.50 Z",
        "braccia": "M 12.05 16.22 C 13.25 16.06 14.28 15.56 15.06 14.65 L 15.23 18.96 C 15.23 19.63 14.71 20.04 14.02 20.04 H 12.48 C 11.87 20.04 11.53 19.63 11.53 18.96 Z M 35.95 16.22 C 34.75 16.06 33.72 15.56 32.94 14.65 L 32.77 18.96 C 32.77 19.63 33.29 20.04 33.98 20.04 H 35.52 C 36.13 20.04 36.47 19.63 36.47 18.96 Z M 11.53 20.87 H 15.06 L 14.54 26.27 C 14.45 26.93 14.02 27.35 13.34 27.35 H 12.48 C 11.87 27.35 11.44 26.93 11.36 26.27 Z M 36.47 20.87 H 32.94 L 33.46 26.27 C 33.55 26.93 33.98 27.35 34.66 27.35 H 35.52 C 36.13 27.35 36.56 26.93 36.64 26.27 Z",
        "gambe": "M 17.53 28.40 C 19.49 29.66 21.35 30.29 23.31 30.42 L 23.02 37.22 H 18.41 C 17.83 34.20 17.34 31.42 17.53 28.40 Z M 30.47 28.40 C 28.51 29.66 26.65 30.29 24.69 30.42 L 24.98 37.22 H 29.59 C 30.17 34.20 30.66 31.42 30.47 28.40 Z M 18.41 38.48 H 23.02 C 23.02 40.50 22.82 42.26 22.53 44.02 L 22.33 46.54 H 19.69 L 19.30 44.02 C 18.81 42.26 18.41 40.50 18.41 38.48 Z M 29.59 38.48 H 24.98 C 24.98 40.50 25.18 42.26 25.47 44.02 L 25.67 46.54 H 28.31 L 28.70 44.02 C 29.19 42.26 29.59 40.50 29.59 38.48 Z",
        "petto": "M 23.40 9.50 C 21.08 9.50 18.93 9.67 17.72 10.41 C 16.95 10.99 16.69 12.16 16.86 13.48 C 17.21 15.64 18.75 16.72 20.90 16.72 C 22.11 16.72 22.97 16.31 23.40 15.64 Z M 24.60 9.50 C 26.92 9.50 29.07 9.67 30.28 10.41 C 31.05 10.99 31.31 12.16 31.14 13.48 C 30.79 15.64 29.25 16.72 27.10 16.72 C 25.89 16.72 25.03 16.31 24.60 15.64 Z",
        "addome": "M 19.18 17.63 H 23.40 V 25.93 C 21.68 25.85 20.13 25.10 19.79 23.94 Z M 28.82 17.63 H 24.60 V 25.93 C 26.32 25.85 27.87 25.10 28.21 23.94 Z",
        "fianchi": "M 16.86 15.14 C 17.38 16.31 18.07 17.05 18.50 17.47 L 18.93 23.78 C 18.24 23.44 17.72 22.78 17.55 21.78 L 16.69 17.97 Z M 31.14 15.14 C 30.62 16.31 29.93 17.05 29.50 17.47 L 29.07 23.78 C 29.76 23.44 30.28 22.78 30.45 21.78 L 31.31 17.97 Z",
        "trapezio": "M 24.00 8.01 C 25.72 9.08 27.78 9.67 30.02 10.00 C 27.96 11.49 25.72 13.82 24.00 16.80 C 22.28 13.82 20.04 11.49 17.98 10.00 C 20.22 9.67 22.28 9.08 24.00 8.01 Z",
        "dorsali": "M 17.29 11.08 C 19.36 12.74 21.42 14.89 23.31 17.97 V 22.95 C 21.51 22.78 19.79 22.28 18.75 21.45 C 17.98 18.96 17.29 16.31 16.78 13.82 Z M 30.71 11.08 C 28.64 12.74 26.58 14.89 24.69 17.97 V 22.95 C 26.49 22.78 28.21 22.28 29.25 21.45 C 30.02 18.96 30.71 16.31 31.22 13.82 Z",
        "lombari": "M 19.01 22.45 C 20.39 23.28 21.76 23.78 23.31 23.94 V 25.93 C 21.68 25.85 20.13 25.10 19.79 23.94 Z M 28.99 22.45 C 27.61 23.28 26.24 23.78 24.69 23.94 V 25.93 C 26.32 25.85 27.87 25.10 28.21 23.94 Z",
    ]

    /// Zone della vista (tutte, nell'ordine di disegno).
    public static func zoneNames(view: View) -> [String] {
        switch view {
        case .front: return ["testa", "collo", "deltoidi", "braccia", "gambe", "petto", "addome", "fianchi"]
        case .back: return ["testa", "collo", "deltoidi", "braccia", "gambe", "trapezio", "dorsali", "lombari"]
        }
    }

    /// Vista usata dal gruppo: la Schiena è vista da dietro, gli altri di fronte.
    public static func view(for group: MuscleGroup) -> View {
        group == .back ? .back : .front
    }

    /// Zone piene del gruppo.
    public static func highlighted(for group: MuscleGroup) -> [String] {
        switch group {
        case .chest: return ["petto"]
        case .back: return ["trapezio", "dorsali"]
        case .shoulders: return ["deltoidi"]
        case .legs: return ["gambe"]
        case .arms: return ["braccia"]
        case .abs: return ["addome"]
        }
    }

    /// Zone della sagoma: tutte quelle della vista tranne quelle piene.
    public static func silhouette(for group: MuscleGroup) -> [String] {
        let full = Set(highlighted(for: group))
        return zoneNames(view: view(for: group)).filter { !full.contains($0) }
    }
}
