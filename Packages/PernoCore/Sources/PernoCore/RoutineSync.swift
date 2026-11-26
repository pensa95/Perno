import Foundation

/// Le modifiche alla scheda arrivano alla sessione aperta (UI v6, task T12).
///
/// La sessione tiene una fotografia della scheda (`EntrySnapshot` per voce) presa all'avvio; dopo ogni
/// salvataggio confronta la scheda di adesso con la fotografia e applica **solo quello che è cambiato nella
/// scheda**, così le modifiche fatte in sessione (set aggiunti o tolti, obiettivi di oggi) restano.
/// Regole: voce aggiunta → in fondo ai «Da fare» («Aggiunto dalla scheda»); voce tolta → l'esercizio sparisce
/// dalla sessione solo se non ha set fatti; set, ripetizioni, recupero, regolazioni e promemoria cambiati →
/// valgono per i set non ancora fatti. I set fatti non si toccano mai.
public enum RoutineSync {
    /// Quello che conta di una voce della scheda per la sessione aperta.
    public struct EntrySnapshot: Equatable, Sendable {
        public var id: UUID
        public var setCount: Int
        public var repsMin: Int
        public var repsMax: Int
        public var fixedRest: Double?
        public var setup: String
        public var cues: String
        public var restMode: String
        public var autoStartAfterRest: Bool

        public init(id: UUID, setCount: Int, repsMin: Int, repsMax: Int, fixedRest: Double?, setup: String,
                    cues: String, restMode: String, autoStartAfterRest: Bool) {
            self.id = id
            self.setCount = setCount
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.fixedRest = fixedRest
            self.setup = setup
            self.cues = cues
            self.restMode = restMode
            self.autoStartAfterRest = autoStartAfterRest
        }
    }

    public struct Changes: Equatable, Sendable {
        /// Voci nuove, nell'ordine della scheda.
        public var added: [UUID] = []
        /// Voci tolte dalla scheda.
        public var removed: [UUID] = []
        /// Voci cambiate: prima e adesso.
        public var changed: [Change] = []

        public var isEmpty: Bool { added.isEmpty && removed.isEmpty && changed.isEmpty }
    }

    public struct Change: Equatable, Sendable {
        public var before: EntrySnapshot
        public var after: EntrySnapshot

        /// Set di lavoro da aggiungere (positivo) o togliere (negativo) nella sessione: la differenza
        /// della scheda, così i set aggiunti o tolti in sessione restano.
        public var workSetDelta: Int { after.setCount - before.setCount }
        public var repsChanged: Bool { before.repsMin != after.repsMin || before.repsMax != after.repsMax }
    }

    public static func changes(from before: [EntrySnapshot], to after: [EntrySnapshot]) -> Changes {
        var result = Changes()
        let beforeByID = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let afterIDs = Set(after.map(\.id))
        for entry in after {
            if let old = beforeByID[entry.id] {
                if old != entry { result.changed.append(Change(before: old, after: entry)) }
            } else {
                result.added.append(entry.id)
            }
        }
        result.removed = before.map(\.id).filter { !afterIDs.contains($0) }
        return result
    }

    /// Ripetizioni obiettivo di un set da fare con l'intervallo nuovo della scheda.
    public static func reps(_ target: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(target, min), Swift.max(min, max))
    }
}
