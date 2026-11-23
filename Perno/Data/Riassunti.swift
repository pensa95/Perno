import Foundation
import PernoCore

extension Routine {
    /// «5 esercizi, circa 55 minuti» (stima di `RoutineSummary`).
    var riassunto: String {
        RoutineSummary.text(orderedEntries.map {
            RoutineSummary.Entry(sets: $0.setCount, approaches: $0.approachCount, fixedRest: $0.fixedRest)
        })
    }
}
