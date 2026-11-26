import Foundation
import SwiftData
import PernoCore

extension WorkoutSession {
    /// Crea il registro di una sessione da una scheda: copia esercizi e parametri (la scheda non
    /// cambia) e prepara avvicinamenti e obiettivi dalla volta precedente (`SessionPlanner`).
    @discardableResult
    static func avvia(da scheda: Routine, alle inizio: Date = .now, in context: ModelContext) -> WorkoutSession {
        let sessione = WorkoutSession(routine: scheda, startedAt: inizio)
        context.insert(sessione)
        for (indice, voce) in scheda.orderedEntries.enumerated() {
            let esercizio = SessionExercise(position: indice, entry: voce)
            context.insert(esercizio)
            esercizio.session = sessione
            let (piano, durata) = pianoDi(voce)
            for (posizione, set) in piano.enumerated() {
                let registrato = SessionSet(position: posizione, kind: set.kind,
                                            targetWeight: set.weight, targetReps: set.reps)
                if voce.isTimed { registrato.targetSeconds = durata }
                context.insert(registrato)
                registrato.sessionExercise = esercizio
            }
        }
        try? context.save()
        return sessione
    }

    /// Set di oggi di una voce della scheda, con gli obiettivi dalle volte precedenti (`SessionPlanner`);
    /// a tempo (UI v5) solo set di lavoro, il peso dell'ultima volta se c'è «Con peso» e la durata di oggi.
    /// Usato all'avvio e per le voci aggiunte alla scheda a sessione aperta (T12).
    static func pianoDi(_ voce: RoutineEntry) -> (piano: [PlannedSet], durata: Int) {
        if voce.isTimed {
            let ultimi = voce.exercise.map { ultimiSetATempo($0) } ?? []
            let peso = voce.withWeight ? (ultimi.first?.weight ?? 0) : 0
            return (TimedPlan.sets(count: voce.setCount, weight: peso),
                    TimedProgression.target(base: voce.targetSeconds, last: ultimi))
        }
        let piano = SessionPlanner.plan(
            workSets: voce.setCount,
            repsMin: voce.repsMin,
            repsMax: voce.repsMax,
            approaches: voce.approachCount,
            history: voce.exercise.map { storiaSetDiLavoro($0) } ?? [],
            step: PlateStep.current
        )
        return (piano, voce.targetSeconds)
    }

    /// Sessione libera: nessun esercizio all'inizio, si aggiungono strada facendo.
    @discardableResult
    static func avviaLibera(alle inizio: Date = .now, in context: ModelContext) -> WorkoutSession {
        let sessione = WorkoutSession(routine: nil, startedAt: inizio)
        context.insert(sessione)
        try? context.save()
        return sessione
    }

    /// Set di lavoro fatti nelle ultime volte (dalla più recente), con faccina e riserva: servono ai
    /// suggerimenti (`Progression`). Solo sessioni chiuse; le volte senza set fatti non contano.
    static func storiaSetDiLavoro(_ esercizio: Exercise, volte: Int = 2) -> [[Progression.WorkSet]] {
        esercizio.sessionExercises
            .filter { $0.session?.endedAt != nil }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
            .map { voce in
                voce.orderedSets.compactMap { set -> Progression.WorkSet? in
                    guard set.kind != .approach, set.isDone, set.targetSeconds == nil,
                          let weight = set.weight, let reps = set.reps else { return nil }
                    return Progression.WorkSet(weight: weight, reps: reps, reserve: set.reserveRaw,
                                               feeling: set.feeling)
                }
            }
            .filter { !$0.isEmpty }
            .prefix(volte)
            .map { $0 }
    }

    /// Set di lavoro fatti l'ultima volta per questo esercizio, in ordine (avvicinamenti esclusi).
    /// Le volte in cui l'esercizio c'era ma nessun set è stato fatto (saltato, rimandato) non contano:
    /// altrimenti la volta dopo l'obiettivo ripartirebbe da zero.
    static func ultimiSetDiLavoro(_ esercizio: Exercise) -> [(weight: Double, reps: Int)] {
        let volte = esercizio.sessionExercises
            .filter { $0.session?.endedAt != nil }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
        for voce in volte {
            let fatti = voce.orderedSets.compactMap { set -> (weight: Double, reps: Int)? in
                guard set.kind != .approach, set.isDone, set.targetSeconds == nil,
                      let weight = set.weight, let reps = set.reps else { return nil }
                return (weight, reps)
            }
            if !fatti.isEmpty { return fatti }
        }
        return []
    }

    /// Set a tempo fatti l'ultima volta per questo esercizio (UI v5): obiettivo, durata e peso.
    /// Come per i set a ripetizioni, le volte senza set fatti non contano.
    static func ultimiSetATempo(_ esercizio: Exercise) -> [TimedSet] {
        let volte = esercizio.sessionExercises
            .filter { $0.session?.endedAt != nil }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
        for voce in volte {
            let fatti = voce.orderedSets.compactMap(\.setATempoFatto)
            if !fatti.isEmpty { return fatti }
        }
        return []
    }
}

extension RoutineEntry {
    /// Fotografia della voce per allineare la sessione aperta alla scheda (T12); `nil` senza identità.
    var fotografia: RoutineSync.EntrySnapshot? {
        entryID.map {
            RoutineSync.EntrySnapshot(id: $0, setCount: setCount, repsMin: repsMin, repsMax: repsMax,
                                      fixedRest: fixedRest, setup: setup, cues: cues, restMode: restModeRaw,
                                      autoStartAfterRest: autoStartAfterRest)
        }
    }
}
