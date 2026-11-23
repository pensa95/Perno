import Foundation

/// Scaletta di oggi: fatti, adesso, da fare (riordinabili) e rimandati. Vale solo per oggi.
public struct Lineup: Equatable, Sendable {
    public var done: [Int]
    public var current: Int?
    public var upcoming: [Int]
    public var postponed: [Int]

    /// Divide l'ordine di oggi: prima della posizione corrente i fatti, poi l'esercizio di adesso,
    /// poi quelli da fare; i rimandati (anche se in mezzo) vanno nella loro sezione, nel loro ordine.
    public init(order: [Int], position: Int, postponed flagged: Set<Int>) {
        let clamped = min(max(position, 0), order.count)
        done = Array(order[..<clamped])
        current = clamped < order.count ? order[clamped] : nil
        let after = clamped < order.count ? Array(order[(clamped + 1)...]) : []
        upcoming = after.filter { !flagged.contains($0) }
        postponed = after.filter { flagged.contains($0) }
    }

    /// Ordine dopo l'esercizio di adesso: da fare, poi rimandati.
    public var tail: [Int] { upcoming + postponed }

    /// «Tieni premuto per spostare» dentro «Da fare».
    public func movingUpcoming(from source: IndexSet, to destination: Int) -> [Int] {
        ListOrder.move(upcoming, from: source, to: destination) + postponed
    }

    /// «Fai dopo questo»: il rimandato passa subito dopo l'esercizio di adesso.
    public func bringingForward(_ exercise: Int) -> [Int] {
        [exercise] + tail.filter { $0 != exercise }
    }
}

public enum LineupText {
    /// «3 di 3»: set di lavoro fatti su quelli previsti.
    public static func progress(done: Int, total: Int) -> String {
        "\(done) di \(total)"
    }

    /// «3 set» (set di lavoro).
    public static func sets(_ count: Int) -> String {
        "\(count) set"
    }

    /// «Macchinario occupato alle 18:20»; senza orario solo «Macchinario occupato».
    public static func postponed(at time: Date?, calendar: Calendar = .current) -> String {
        guard let time else { return "Macchinario occupato" }
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        let minute = parts.minute ?? 0
        return "Macchinario occupato alle \(parts.hour ?? 0):\(minute < 10 ? "0" : "")\(minute)"
    }

    /// «Upper body, oggi. La scheda non cambia».
    public static func subtitle(routine: String) -> String {
        routine.isEmpty ? "Oggi. La scheda non cambia" : "\(routine), oggi. La scheda non cambia"
    }
}
