import Foundation

/// Recupero: cronometro (in avanti) o conto alla rovescia.
public enum RestMode: String, CaseIterable, Sendable {
    case stopwatch
    case countdown

    public var toggled: RestMode { self == .stopwatch ? .countdown : .stopwatch }
}

/// Durata e testo del recupero nel dock.
public enum RestTimer {
    /// Senza recupero fissato e senza tempi misurati si parte da 2:00.
    public static let defaultDuration: TimeInterval = 120
    /// «+15 s».
    public static let extraStep: TimeInterval = 15

    /// Durata del conto alla rovescia: il recupero fissato nella scheda, altrimenti il recupero
    /// abituale arrotondato ai 5 secondi, altrimenti 2:00.
    public static func duration(fixed: TimeInterval?, usual: TimeInterval?) -> TimeInterval {
        if let fixed, fixed > 0 { return fixed }
        if let usual, usual > 0 { return max(5, (usual / 5).rounded() * 5) }
        return defaultDuration
    }

    /// Tempo nel dock. Cronometro: «1:42». Conto alla rovescia: il tempo che resta («0:28»);
    /// a zero il dock resta blu e conta il tempo in più («+0:12»).
    public static func display(mode: RestMode, elapsed: TimeInterval, duration: TimeInterval) -> String {
        switch mode {
        case .stopwatch:
            return SessionText.clock(elapsed)
        case .countdown:
            let remaining = duration - elapsed
            if remaining > 0 {
                return SessionText.clock(remaining.rounded(.up))
            }
            return "+" + SessionText.clock(-remaining)
        }
    }

    /// Etichetta del dock: «Recupero, fissato a 2:00» se fissato, altrimenti come `SessionText.restLabel`.
    public static func label(fixed: TimeInterval?, usual: TimeInterval?) -> String {
        if let fixed, fixed > 0 { return "Recupero, fissato a \(SessionText.clock(fixed))" }
        return SessionText.restLabel(usual: usual)
    }
}
