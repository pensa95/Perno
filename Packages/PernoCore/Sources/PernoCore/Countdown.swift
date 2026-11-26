import Foundation

/// Il 3-2-1 prima di ogni set (UI v6): dura sempre 3 secondi, senza opzione per toglierlo.
///
/// Numeri, anello e bip partono dallo **stesso istante**, `start(since:)`: il tocco su «Inizia» più un
/// piccolo anticipo (`lead`), il tempo che serve all'app per programmare l'audio esattamente su quell'istante.
/// Durante l'anticipo si vede «3» con l'anello pieno. Così ogni bip cade al cambio del numero.
/// La fase `countdown(since:)` della macchina resta legata al tocco: il recupero finisce lì (3-2-1 escluso).
public enum Countdown {
    /// Durata del 3-2-1 in secondi.
    public static let seconds = 3
    /// Anticipo tra il tocco e l'inizio di numeri, anello e bip.
    public static let lead: TimeInterval = 0.3

    /// Istante in cui compaiono il «3» e il primo bip.
    public static func start(since: Date) -> Date {
        since.addingTimeInterval(lead)
    }

    /// Fine del 3-2-1: il «via» e la partenza del set.
    public static func end(since: Date) -> Date {
        start(since: since).addingTimeInterval(TimeInterval(seconds))
    }

    /// Istanti dei bip «3», «2», «1» (il «via» è `end`).
    public static func beeps(since: Date) -> [Date] {
        let inizio = start(since: since)
        return (0..<seconds).map { inizio.addingTimeInterval(TimeInterval($0)) }
    }

    /// Numero da mostrare adesso: 3, 2, 1 (3 anche durante l'anticipo).
    public static func value(at now: Date, since: Date) -> Int {
        SessionText.countdownValue(elapsed: now.timeIntervalSince(start(since: since)), total: seconds)
    }

    /// Parte dell'anello ancora piena, da 1 (inizio e anticipo) a 0 (via).
    public static func remaining(at now: Date, since: Date) -> Double {
        let trascorsi = now.timeIntervalSince(start(since: since))
        return min(1, max(0, 1 - trascorsi / TimeInterval(seconds)))
    }
}
