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

    /// Durata del movimento con cui l'anello consuma un terzo: finisce esattamente sul bip.
    public static let ringMove: TimeInterval = 0.45

    /// Parte dell'anello ancora piena, **a scatti** (UI v6): piena fino a `start`, poi ogni terzo si consuma con
    /// un movimento ease-in-out di `ringMove` secondi che arriva sul bip successivo e lì resta fermo:
    /// 2/3 a start+1, 1/3 a start+2, 0 a start+3 (il «via»). Funzione pura del tempo.
    public static func ring(at now: Date, since: Date) -> Double {
        let trascorsi = now.timeIntervalSince(start(since: since))
        var consumato = 0.0
        for passo in 1...seconds {
            let inizio = TimeInterval(passo) - ringMove
            let avanzamento = min(1, max(0, (trascorsi - inizio) / ringMove))
            consumato += avanzamento * avanzamento * (3 - 2 * avanzamento) // ease-in-out
        }
        return max(0, 1 - consumato / Double(seconds))
    }
}
