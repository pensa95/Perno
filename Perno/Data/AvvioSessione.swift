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
            let piano = SessionPlanner.plan(
                workSets: voce.setCount,
                repsMin: voce.repsMin,
                approaches: voce.approachCount,
                previous: voce.exercise.map(ultimiSetDiLavoro) ?? [],
                step: PlateStep.current
            )
            for (posizione, set) in piano.enumerated() {
                let registrato = SessionSet(position: posizione, kind: set.kind,
                                            targetWeight: set.weight, targetReps: set.reps)
                context.insert(registrato)
                registrato.sessionExercise = esercizio
            }
        }
        try? context.save()
        return sessione
    }

    /// Sessione libera: nessun esercizio all'inizio, si aggiungono strada facendo.
    @discardableResult
    static func avviaLibera(alle inizio: Date = .now, in context: ModelContext) -> WorkoutSession {
        let sessione = WorkoutSession(routine: nil, startedAt: inizio)
        context.insert(sessione)
        try? context.save()
        return sessione
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
                guard set.kind != .approach, set.isDone, let weight = set.weight, let reps = set.reps else { return nil }
                return (weight, reps)
            }
            if !fatti.isEmpty { return fatti }
        }
        return []
    }
}
