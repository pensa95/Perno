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

// MARK: - Riepilogo

extension WorkoutSession {
    /// Fine per il riepilogo di una sessione senza schermata aperta: quella salvata, altrimenti
    /// l'ultimo «Set fatto» (o l'ultimo tocco).
    var fineRegistrata: Date {
        endedAt ?? AutoClose.end(lastSetEnd: exercises.flatMap(\.sets).compactMap(\.endedAt).max(),
                                 lastActivity: lastActivityAt)
    }

    /// Kg della volta scorsa con la stessa scheda (sessioni chiuse prima di questa); `nil` per la
    /// sessione libera o la prima volta.
    var chiliVoltaScorsa: Double? {
        guard !isFree, let routine else { return nil }
        let precedente = routine.sessions
            .filter { $0.id != self.id && $0.endedAt != nil && $0.startedAt < self.startedAt }
            .max { $0.startedAt < $1.startedAt }
        return precedente?.chiliSollevati
    }

    /// Esercizi con set di lavoro non fatti, nell'ordine di oggi.
    var setNonFatti: [(esercizio: SessionExercise, conto: Int)] {
        orderedExercises.compactMap { esercizio in
            let conto = esercizio.sets.filter { $0.kind != .approach && !$0.isDone }.count
            return conto > 0 ? (esercizio, conto) : nil
        }
    }

    /// Record di oggi: per esercizio, il set con il massimale stimato più alto di sempre
    /// (confrontato con le sessioni chiuse prima di questa).
    var record: [SessionSummary.Record] {
        orderedExercises.compactMap { voce in
            guard let esercizio = voce.exercise else { return nil }
            let oggi = voce.sets.compactMap(Self.alzata)
            let prima = esercizio.sessionExercises
                .filter { altra in
                    guard let sessione = altra.session else { return false }
                    return sessione.id != self.id && sessione.endedAt != nil && sessione.startedAt < self.startedAt
                }
                .flatMap(\.sets)
                .compactMap(Self.alzata)
            return SessionSummary.record(exercise: voce.name, today: oggi, previous: prima)
        }
    }

    private static func alzata(_ set: SessionSet) -> SessionSummary.Lift? {
        guard set.isDone, set.kind != .approach, let peso = set.weight, let ripetizioni = set.reps else { return nil }
        return SessionSummary.Lift(weight: peso, reps: ripetizioni)
    }

    /// Riscaldamento, lavoro, recupero e cambi per la barra del tempo.
    var tempi: TimeBreakdown {
        let fatti = exercises.flatMap(\.sets).compactMap { set -> CompletedSet? in
            guard let fine = set.endedAt, let inizio = set.startedAt else { return nil }
            return CompletedSet(exerciseIndex: 0, setIndex: 0, kind: set.kind, weight: set.weight ?? 0,
                                reps: set.reps ?? 0, startedAt: inizio, endedAt: fine)
        }
        let pause = pauses.map {
            Pause(kind: $0.kind, exerciseIndex: nil, afterApproach: $0.afterApproach, start: $0.start, end: $0.end)
        }
        return SessionStats.breakdown(sets: fatti, pauses: pause)
    }
}
