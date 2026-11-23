import Foundation

/// Preparazione della sessione: avvicinamenti e obiettivi di ogni set, dalla volta precedente.
public enum SessionPlanner {
    /// Ripetizioni degli avvicinamenti. Per 2 set la tavola «2 Cambio esercizio» mostra 10 e 6
    /// (30 × 10 al 50%, 45 × 6 al 75%); per 1 e 3 set è una regola provvisoria, da confermare.
    public static func approachReps(count: Int) -> [Int] {
        switch count {
        case 1: return [8]
        case 2: return [10, 6]
        case 3: return [10, 6, 3]
        default: return []
        }
    }

    /// Set da fare per un esercizio: prima gli avvicinamenti, poi i set di lavoro.
    /// - `previous`: set di lavoro fatti l'ultima volta, in ordine (peso in chili, ripetizioni).
    /// - Peso di lavoro di oggi: il più alto dell'ultima volta (0 se è la prima volta).
    /// - Ripetizioni di ogni set: quelle dello stesso set l'ultima volta (o dell'ultimo set fatto);
    ///   la prima volta, il minimo dell'intervallo.
    /// - Avvicinamenti: percentuali del peso di lavoro di oggi, arrotondate al passo dei dischi.
    public static func plan(
        workSets: Int,
        repsMin: Int,
        approaches: Int,
        previous: [(weight: Double, reps: Int)],
        step: Double
    ) -> [PlannedSet] {
        let workWeight = previous.map(\.weight).max() ?? 0
        let approachWeights = Approach.weights(count: approaches, workWeight: workWeight, step: step)
        let approachSets = zip(approachWeights, approachReps(count: approaches)).map {
            PlannedSet(kind: .approach, weight: $0.0, reps: $0.1)
        }
        let work = (0..<max(workSets, 0)).map { index -> PlannedSet in
            let reps = index < previous.count ? previous[index].reps : (previous.last?.reps ?? repsMin)
            return PlannedSet(kind: .work, weight: workWeight, reps: EntryLimits.clamp(reps, EntryLimits.reps))
        }
        return approachSets + work
    }
}
