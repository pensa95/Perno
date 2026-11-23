import Foundation
import PernoCore

extension Routine {
    /// Esercizi della scheda per la stima della durata.
    var vociStima: [RoutineSummary.Entry] {
        orderedEntries.map {
            RoutineSummary.Entry(sets: $0.setCount, approaches: $0.approachCount, fixedRest: $0.fixedRest)
        }
    }

    /// «5 esercizi, circa 55 minuti» (stima di `RoutineSummary`).
    var riassunto: String {
        RoutineSummary.text(vociStima)
    }

    /// Nomi degli esercizi in ordine.
    var nomiEsercizi: [String] {
        orderedEntries.compactMap { $0.exercise?.name }
    }

    /// «Chest press, Lat machine, Shoulder press e altri 2, circa 55 minuti».
    var elencoConDurata: String {
        HomeText.exercises(nomiEsercizi, minutes: RoutineSummary.estimatedMinutes(vociStima))
    }
}

extension WorkoutSession {
    /// Set di lavoro (avvicinamenti esclusi).
    private var setDiLavoro: [SessionSet] {
        exercises.flatMap(\.sets).filter { $0.kind != .approach }
    }

    var setFatti: Int { setDiLavoro.filter(\.isDone).count }
    var setPrevisti: Int { setDiLavoro.count }

    /// Durata da inizio a fine (fino ad adesso se è in corso).
    var durata: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }

    /// Chili sollevati nei set fatti, avvicinamenti esclusi.
    var chiliSollevati: Double {
        HomeText.liftedKilograms(exercises.flatMap(\.sets).compactMap { set -> (kind: SetKind, weight: Double, reps: Int)? in
            guard set.isDone, let weight = set.weight, let reps = set.reps else { return nil }
            return (set.kind, weight, reps)
        })
    }

    var titolo: String { isFree || routineName.isEmpty ? "Sessione libera" : routineName }
}
