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

// MARK: - Suggerimenti

/// Progressione a regole, offline: decide il peso e le ripetizioni di oggi dalle ultime volte.
public enum Progression {
    /// Scarico dopo due volte sotto il minimo: peso di lavoro al 90%, arrotondato al passo dei dischi.
    public static let deloadFactor = 0.9

    /// Set di lavoro fatto (peso in chili) con l'eventuale riserva (0…4).
    public struct WorkSet: Equatable, Sendable {
        public var weight: Double
        public var reps: Int
        public var reserve: Int?

        public init(weight: Double, reps: Int, reserve: Int? = nil) {
            self.weight = weight
            self.reps = reps
            self.reserve = reserve
        }
    }

    public enum Decision: Equatable, Sendable {
        /// Prima volta: peso da impostare, minimo dell'intervallo.
        case firstTime
        /// Come l'ultima volta (stesso peso, stesse ripetizioni set per set).
        case repeatLast
        /// Tutti i set al massimo dell'intervallo: + passo dei dischi, si riparte dal minimo.
        case increase(to: Double)
        /// Al massimo dell'intervallo ma con riserva 0 su tutti i set: si mantiene.
        case holdNoReserve
        /// Sotto il minimo per la seconda volta di fila: scarico, si riparte dal minimo.
        case deload(to: Double)
    }

    /// Regole (funzionalità, sezione 6):
    /// - tutti i set di lavoro dell'ultima volta (almeno quanti quelli di oggi) al peso più alto e al
    ///   massimo dell'intervallo → + passo dei dischi e ripetizioni dal minimo;
    /// - … ma con riserva 0 su tutti i set (data per tutti) → si mantiene;
    /// - almeno un set sotto il minimo l'ultima volta e anche quella prima → scarico al 90%;
    ///   una volta sola → si mantiene;
    /// - altrimenti si ripete l'ultima volta.
    /// `history`: set di lavoro fatti nelle ultime volte, dalla più recente.
    public static func decide(history: [[WorkSet]], workSets: Int, repsMin: Int, repsMax: Int,
                              step: Double) -> Decision {
        guard let last = history.first, let top = last.map(\.weight).max() else { return .firstTime }
        let belowMin: ([WorkSet]) -> Bool = { sets in sets.contains { $0.reps < repsMin } }
        if belowMin(last), history.count >= 2, belowMin(history[1]), top > 0 {
            let lighter = Weights.round(top * deloadFactor, step: step)
            if lighter < top - 0.001 { return .deload(to: max(0, lighter)) }
        }
        let allAtMax = last.count >= max(workSets, 1)
            && last.allSatisfy { $0.weight >= top - 0.001 && $0.reps >= repsMax }
        if allAtMax {
            let reserves = last.map(\.reserve)
            if reserves.allSatisfy({ $0 == 0 }) { return .holdNoReserve }
            return .increase(to: top + step)
        }
        return .repeatLast
    }
}

extension SessionPlanner {
    /// Set da fare con i suggerimenti (`Progression`): prima gli avvicinamenti, poi i set di lavoro.
    /// Ripetendo o mantenendo vale `plan(…previous:…)`; aumentando o scaricando il peso di lavoro
    /// cambia per tutti i set e le ripetizioni ripartono dal minimo dell'intervallo.
    public static func plan(
        workSets: Int,
        repsMin: Int,
        repsMax: Int,
        approaches: Int,
        history: [[Progression.WorkSet]],
        step: Double
    ) -> [PlannedSet] {
        let previous = (history.first ?? []).map { (weight: $0.weight, reps: $0.reps) }
        let decision = Progression.decide(history: history, workSets: workSets, repsMin: repsMin,
                                          repsMax: repsMax, step: step)
        let newWeight: Double
        switch decision {
        case .firstTime, .repeatLast, .holdNoReserve:
            return plan(workSets: workSets, repsMin: repsMin, approaches: approaches, previous: previous, step: step)
        case let .increase(to), let .deload(to):
            newWeight = to
        }
        let approachWeights = Approach.weights(count: approaches, workWeight: newWeight, step: step)
        let approachSets = zip(approachWeights, approachReps(count: approaches)).map {
            PlannedSet(kind: .approach, weight: $0.0, reps: $0.1)
        }
        let reps = EntryLimits.clamp(repsMin, EntryLimits.reps)
        let work = (0..<max(workSets, 0)).map { _ in PlannedSet(kind: .work, weight: newWeight, reps: reps) }
        return approachSets + work
    }
}
