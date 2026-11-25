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

    /// Chili sollevati nei set fatti, avvicinamenti e set a tempo esclusi.
    var chiliSollevati: Double {
        SessionSummary.liftedKilogramsExcludingTimed(exercises.flatMap(\.sets).compactMap { set in
            guard set.isDone, let weight = set.weight, let reps = set.reps else { return nil }
            return (set.kind, weight, reps, set.aTempo)
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
    /// Per gli esercizi a tempo il record è la durata più lunga (UI v5).
    var record: [SessionSummary.Record] {
        orderedExercises.compactMap { voce in
            guard let esercizio = voce.exercise else { return nil }
            let primaSet = esercizio.sessionExercises
                .filter { altra in
                    guard let sessione = altra.session else { return false }
                    return sessione.id != self.id && sessione.endedAt != nil && sessione.startedAt < self.startedAt
                }
                .flatMap(\.sets)
            if voce.isTimed {
                return SessionSummary.timedRecord(exercise: voce.name,
                                                  today: voce.sets.compactMap(\.setATempoFatto),
                                                  previous: primaSet.compactMap(\.setATempoFatto),
                                                  withWeight: voce.withWeight)
            }
            return SessionSummary.record(exercise: voce.name, today: voce.sets.compactMap(Self.alzata),
                                         previous: primaSet.compactMap(Self.alzata))
        }
    }

    private static func alzata(_ set: SessionSet) -> SessionSummary.Lift? {
        guard set.isDone, set.kind != .approach, !set.aTempo,
              let peso = set.weight, let ripetizioni = set.reps else { return nil }
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

// MARK: - Storico

extension WorkoutSession {
    /// Nello storico: chiusa, esclusa quella chiusa da sola e non ancora salvata.
    var nelloStorico: Bool { endedAt != nil && !(closedAutomatically && !isSaved) }

    /// Set di lavoro fatti di un esercizio, come alzate (pesi in chili).
    static func alzate(_ voce: SessionExercise) -> [SessionSummary.Lift] {
        voce.orderedSets.compactMap { set in
            guard set.isDone, set.kind != .approach, !set.aTempo,
                  let peso = set.weight, let ripetizioni = set.reps else { return nil }
            return SessionSummary.Lift(weight: peso, reps: ripetizioni)
        }
    }
}

extension Exercise {
    /// Volte nello storico, dalla più recente: sessione e set di lavoro fatti.
    var volteNelloStorico: [(sessione: WorkoutSession, alzate: [SessionSummary.Lift])] {
        sessionExercises.compactMap { voce -> (sessione: WorkoutSession, alzate: [SessionSummary.Lift])? in
            guard let sessione = voce.session, sessione.nelloStorico else { return nil }
            let alzate = WorkoutSession.alzate(voce)
            return alzate.isEmpty ? nil : (sessione, alzate)
        }
        .sorted { $0.sessione.startedAt > $1.sessione.startedAt }
    }

    /// L'esercizio come lo vede lo Storico (record, ultima volta, grafico).
    var storico: ExerciseHistory.Exercise<UUID> { storico(da: volteNelloStorico) }

    /// Come `storico`, dalle volte già lette (per non scorrere le sessioni due volte).
    func storico(da volte: [(sessione: WorkoutSession, alzate: [SessionSummary.Lift])]) -> ExerciseHistory.Exercise<UUID> {
        ExerciseHistory.Exercise(id: id, name: name, entries: volte.map {
            ExerciseHistory.Entry(date: $0.sessione.startedAt, lifts: $0.alzate)
        })
    }

    /// Recupero abituale dai recuperi registrati (esclusi avvicinamenti e cambi).
    var recuperoAbituale: Double? {
        let durate = sessionExercises
            .flatMap(\.pauses)
            .filter { $0.kind == .rest && !$0.afterApproach }
            .sorted { $0.start < $1.start }
            .map(\.duration)
        return SessionStats.usualRest(restDurations: durate)
    }
}

// MARK: - Set a tempo (UI v5)

extension SessionSet {
    /// Set di un esercizio a tempo (ha una durata obiettivo).
    var aTempo: Bool { targetSeconds != nil }

    /// Set a tempo fatto (avvicinamenti esclusi): obiettivo, durata fatta e peso.
    var setATempoFatto: TimedSet? {
        guard isDone, kind != .approach, let obiettivo = targetSeconds else { return nil }
        return TimedSet(target: obiettivo, seconds: seconds ?? obiettivo, weight: weight ?? targetWeight)
    }

    /// Valore da mostrare: «62,5 × 10», a tempo «10 × 0:45» o «0:45» (fatto o obiettivo).
    var testoValore: String {
        let peso = isDone ? (weight ?? targetWeight) : targetWeight
        if let obiettivo = targetSeconds {
            let secondi = isDone ? (seconds ?? obiettivo) : obiettivo
            return TimedText.value(seconds: secondi, weight: sessionExercise?.withWeight == true ? peso : nil)
        }
        return SessionText.weightReps(peso, isDone ? (reps ?? targetReps) : targetReps)
    }
}
