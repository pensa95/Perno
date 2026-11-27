import Foundation

/// Eliminazione con «Annulla» (D6): la sessione sparisce subito dalle liste e compare il toast
/// «Sessione eliminata · Annulla» per 5 s; allo scadere si cancella davvero. Se l'app si chiude prima, gli
/// identificativi restano salvati e la cancellazione avviene al prossimo avvio.
/// Qui solo la logica pura (insieme degli identificativi nascosti e loro salvataggio); i dati li tocca l'app.
public struct PendingDeletions: Equatable, Sendable {
    /// Secondi in cui «Annulla» resta disponibile.
    public static let undoDuration: TimeInterval = 5
    public static let sessionDeletedTitle = "Sessione eliminata"
    public static let undoTitle = "Annulla"

    /// Identificativi nascosti, in attesa di essere cancellati.
    public private(set) var ids: Set<UUID>

    public init(ids: Set<UUID> = []) {
        self.ids = ids
    }

    public var isEmpty: Bool { ids.isEmpty }

    public func isHidden(_ id: UUID) -> Bool { ids.contains(id) }

    /// Nasconde l'elemento: da qui in poi liste e conteggi lo ignorano.
    public mutating func hide(_ id: UUID) { ids.insert(id) }

    /// «Annulla»: l'elemento torna visibile. `false` se non era in attesa (già cancellato).
    @discardableResult
    public mutating func undo(_ id: UUID) -> Bool { ids.remove(id) != nil }

    /// Cancellazione fatta (o rinunciata): non serve più tenerne il segno.
    public mutating func finish(_ id: UUID) { ids.remove(id) }

    /// Elementi visibili: tolti quelli nascosti.
    public func visible<T>(_ items: [T], id: (T) -> UUID) -> [T] {
        ids.isEmpty ? items : items.filter { !ids.contains(id($0)) }
    }

    // MARK: Salvataggio

    /// Per UserDefaults: gli identificativi come testi ordinati.
    public var stored: [String] { ids.map(\.uuidString).sorted() }

    /// Dal salvataggio; i testi non validi si scartano.
    public init(stored: [String]) {
        self.ids = Set(stored.compactMap(UUID.init(uuidString:)))
    }
}
