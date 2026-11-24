import Foundation
import SwiftData
import PernoCore

/// Passaggio tra il database (SwiftData) e il file di backup (`BackupFile` di PernoCore).
extension BackupFile {
    /// Fotografia di tutti i dati dell'app.
    static func dalDatabase(_ context: ModelContext, alle ora: Date = .now) throws -> BackupFile {
        let esercizi = try context.fetch(FetchDescriptor<SchemaV1.Exercise>(sortBy: [SortDescriptor(\.createdAt)]))
        let schede = try context.fetch(FetchDescriptor<SchemaV1.Routine>(sortBy: [SortDescriptor(\.createdAt)]))
        let giorni = try context.fetch(FetchDescriptor<SchemaV1.PlanDay>(sortBy: [SortDescriptor(\.weekday)]))
        let sessioni = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))

        return BackupFile(
            createdAt: ora,
            exercises: esercizi.map {
                Exercise(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroupRaw, equipment: $0.equipmentRaw,
                         type: $0.typeRaw, builtInKey: $0.builtInKey, createdAt: $0.createdAt)
            },
            routines: schede.map { scheda in
                Routine(id: scheda.id, name: scheda.name, createdAt: scheda.createdAt,
                        entries: scheda.orderedEntries.map {
                            Entry(position: $0.position, exerciseID: $0.exercise?.id, setCount: $0.setCount,
                                  repsMin: $0.repsMin, repsMax: $0.repsMax, approachCount: $0.approachCount,
                                  fixedRest: $0.fixedRest, setup: $0.setup, cues: $0.cues)
                        })
            },
            planDays: giorni.map { PlanDay(weekday: $0.weekday, routineID: $0.routine?.id) },
            sessions: sessioni.map { sessione in
                Session(id: sessione.id, routineID: sessione.routine?.id, routineName: sessione.routineName,
                        isFree: sessione.isFree, startedAt: sessione.startedAt, endedAt: sessione.endedAt,
                        lastActivityAt: sessione.lastActivityAt,
                        closedAutomatically: sessione.closedAutomatically, isSaved: sessione.isSaved,
                        note: sessione.note,
                        exercises: sessione.orderedExercises.map { esercizio in
                            SessionExercise(position: esercizio.position, exerciseID: esercizio.exercise?.id,
                                            name: esercizio.name, repsMin: esercizio.repsMin,
                                            repsMax: esercizio.repsMax, approachCount: esercizio.approachCount,
                                            fixedRest: esercizio.fixedRest, setup: esercizio.setup,
                                            cues: esercizio.cues, note: esercizio.note,
                                            isPostponed: esercizio.isPostponed,
                                            sets: esercizio.orderedSets.map {
                                                SessionSet(position: $0.position, kind: $0.kindRaw,
                                                           targetWeight: $0.targetWeight, targetReps: $0.targetReps,
                                                           weight: $0.weight, reps: $0.reps, reserve: $0.reserveRaw,
                                                           startedAt: $0.startedAt, endedAt: $0.endedAt)
                                            })
                        },
                        pauses: sessione.orderedPauses.map {
                            Pause(kind: $0.kindRaw, exercisePosition: $0.sessionExercise?.position,
                                  afterApproach: $0.afterApproach, start: $0.start, end: $0.end)
                        })
            }
        )
    }

    /// «Ripristina»: sostituisce tutti i dati del telefono con quelli del backup.
    func ripristina(in context: ModelContext) throws {
        for sessione in try context.fetch(FetchDescriptor<WorkoutSession>()) { context.delete(sessione) }
        for giorno in try context.fetch(FetchDescriptor<SchemaV1.PlanDay>()) { context.delete(giorno) }
        for scheda in try context.fetch(FetchDescriptor<SchemaV1.Routine>()) { context.delete(scheda) }
        for esercizio in try context.fetch(FetchDescriptor<SchemaV1.Exercise>()) { context.delete(esercizio) }
        try context.save()

        var esercizi: [UUID: SchemaV1.Exercise] = [:]
        for voce in exercises {
            let esercizio = SchemaV1.Exercise(name: voce.name, muscleGroup: .chest, equipment: .other,
                                              builtInKey: voce.builtInKey, createdAt: voce.createdAt)
            esercizio.id = voce.id
            esercizio.muscleGroupRaw = voce.muscleGroup
            esercizio.equipmentRaw = voce.equipment
            esercizio.typeRaw = voce.type
            context.insert(esercizio)
            esercizi[voce.id] = esercizio
        }

        var schede: [UUID: SchemaV1.Routine] = [:]
        for voce in routines {
            let scheda = SchemaV1.Routine(name: voce.name, createdAt: voce.createdAt)
            scheda.id = voce.id
            context.insert(scheda)
            schede[voce.id] = scheda
            for riga in voce.entries {
                let entry = RoutineEntry(position: riga.position, exercise: riga.exerciseID.flatMap { esercizi[$0] },
                                         setCount: riga.setCount, repsMin: riga.repsMin, repsMax: riga.repsMax,
                                         approachCount: riga.approachCount, fixedRest: riga.fixedRest,
                                         setup: riga.setup, cues: riga.cues)
                context.insert(entry)
                entry.routine = scheda
            }
        }

        for voce in planDays {
            context.insert(SchemaV1.PlanDay(weekday: voce.weekday, routine: voce.routineID.flatMap { schede[$0] }))
        }

        for voce in sessions {
            let sessione = WorkoutSession(routine: voce.routineID.flatMap { schede[$0] }, startedAt: voce.startedAt)
            sessione.id = voce.id
            sessione.routineName = voce.routineName
            sessione.isFree = voce.isFree
            sessione.endedAt = voce.endedAt
            sessione.lastActivityAt = voce.lastActivityAt
            sessione.closedAutomatically = voce.closedAutomatically
            sessione.isSaved = voce.isSaved
            sessione.note = voce.note
            context.insert(sessione)

            var perPosizione: [Int: SchemaV1.SessionExercise] = [:]
            for riga in voce.exercises {
                let esercizio = SchemaV1.SessionExercise(
                    position: riga.position, exercise: riga.exerciseID.flatMap { esercizi[$0] }, name: riga.name,
                    repsMin: riga.repsMin, repsMax: riga.repsMax, approachCount: riga.approachCount,
                    fixedRest: riga.fixedRest, setup: riga.setup, cues: riga.cues)
                esercizio.note = riga.note
                esercizio.isPostponed = riga.isPostponed
                context.insert(esercizio)
                esercizio.session = sessione
                perPosizione[riga.position] = esercizio
                for set in riga.sets {
                    let registrato = SchemaV1.SessionSet(position: set.position, kind: .work,
                                                         targetWeight: set.targetWeight, targetReps: set.targetReps)
                    registrato.kindRaw = set.kind
                    registrato.weight = set.weight
                    registrato.reps = set.reps
                    registrato.reserveRaw = set.reserve
                    registrato.startedAt = set.startedAt
                    registrato.endedAt = set.endedAt
                    context.insert(registrato)
                    registrato.sessionExercise = esercizio
                }
            }

            for riga in voce.pauses {
                let pausa = SchemaV1.SessionPause(kind: .rest,
                                                  sessionExercise: riga.exercisePosition.flatMap { perPosizione[$0] },
                                                  afterApproach: riga.afterApproach, start: riga.start, end: riga.end)
                pausa.kindRaw = riga.kind
                context.insert(pausa)
                pausa.session = sessione
            }
        }
        try context.save()
    }
}
