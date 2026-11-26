import Foundation
import SwiftData
import PernoCore

// Modello dati della v3 (UI v6). Stesse regole della v1 (vedi `SchemaV1`); i campi della v2 (esercizi a
// tempo) restano. Novità rispetto alla v2, tutte facoltative o con un valore predefinito, in una sola
// migrazione (tappa `v2ToV3` in `PernoMigrationPlan`, che poi riempie i valori iniziali):
// - `SessionSet.feelingRaw`: «Com'è andato?» (`Feeling`: leggero / giusto / faticoso). La riserva resta
//   per i dati vecchi;
// - `RoutineEntry`: `entryID` (identità della voce, per legare le sessioni alla scheda), `restModeRaw`
//   (cronometro / alla rovescia) e `autoStartAfterRest` («Parti da solo a fine recupero»);
// - `SessionExercise`: `routineEntryID` (voce della scheda da cui viene; `nil` = aggiunto in sessione o
//   sostitutivo, task T10), `addedFromRoutine` («Aggiunto dalla scheda» a sessione aperta, T12),
//   `restModeRaw` e `autoStartAfterRest` copiati dalla scheda (in sessione cambiano solo per oggi, T14).
// Sostituisci (T10) e Obiettivi di oggi (T11) non servono campi: si cambiano i set della sessione.

enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            Routine.self,
            RoutineEntry.self,
            PlanDay.self,
            WorkoutSession.self,
            SessionExercise.self,
            SessionSet.self,
            SessionPause.self,
        ]
    }
}

extension SchemaV3 {
    // MARK: Libreria

    /// Esercizio della libreria.
    @Model
    final class Exercise {
        @Attribute(.unique) var id: UUID
        var name: String
        var muscleGroupRaw: String
        var equipmentRaw: String
        var typeRaw: String
        /// Chiave dell'esercizio precaricato (`ExerciseLibrary`); `nil` se creato dall'utente.
        var builtInKey: String?
        var createdAt: Date

        @Relationship(deleteRule: .nullify, inverse: \RoutineEntry.exercise)
        var routineEntries: [RoutineEntry] = []

        @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
        var sessionExercises: [SessionExercise] = []

        init(name: String, muscleGroup: MuscleGroup, equipment: Equipment,
             type: ExerciseType = .weights, builtInKey: String? = nil, createdAt: Date = .now) {
            self.id = UUID()
            self.name = name
            self.muscleGroupRaw = muscleGroup.rawValue
            self.equipmentRaw = equipment.rawValue
            self.typeRaw = type.rawValue
            self.builtInKey = builtInKey
            self.createdAt = createdAt
        }

        convenience init(entry: LibraryEntry) {
            self.init(name: entry.name, muscleGroup: entry.group, equipment: entry.equipment,
                      type: entry.type, builtInKey: entry.key)
        }

        var muscleGroup: MuscleGroup {
            get { MuscleGroup(rawValue: muscleGroupRaw) ?? .chest }
            set { muscleGroupRaw = newValue.rawValue }
        }

        var equipment: Equipment {
            get { Equipment(rawValue: equipmentRaw) ?? .other }
            set { equipmentRaw = newValue.rawValue }
        }

        var type: ExerciseType {
            get { ExerciseType(rawValue: typeRaw) ?? .weights }
            set { typeRaw = newValue.rawValue }
        }
    }

    // MARK: Schede e piano

    /// Scheda.
    @Model
    final class Routine {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \RoutineEntry.routine)
        var entries: [RoutineEntry] = []

        /// Giorni del piano: se la scheda si elimina, quei giorni diventano riposo.
        @Relationship(deleteRule: .nullify, inverse: \PlanDay.routine)
        var planDays: [PlanDay] = []

        /// Sessioni fatte con questa scheda: restano nello storico se la scheda si elimina.
        @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.routine)
        var sessions: [WorkoutSession] = []

        init(name: String, createdAt: Date = .now) {
            self.id = UUID()
            self.name = name
            self.createdAt = createdAt
        }

        var orderedEntries: [RoutineEntry] {
            entries.sorted { $0.position < $1.position }
        }
    }

    /// Esercizio nella scheda, con i suoi parametri.
    @Model
    final class RoutineEntry {
        var position: Int
        var routine: Routine?
        var exercise: Exercise?
        var setCount: Int
        var repsMin: Int
        var repsMax: Int
        /// Avvicinamento: 0 = Nessuno, oppure 1, 2, 3 set (vedi `Approach`).
        var approachCount: Int
        /// Recupero fissato in secondi; `nil` = «dai tuoi tempi» (recupero abituale).
        var fixedRest: Double?
        /// Regolazioni del macchinario («Sedile 4, schienale 30°»).
        var setup: String
        /// Promemoria tecnici («Scapole addotte»).
        var cues: String
        /// Ripetizioni o tempo (`SetMeasure`), v2.
        var measureRaw: String = SetMeasure.reps.rawValue
        /// Durata obiettivo di ogni set a tempo, in secondi (v2).
        var targetSeconds: Int = DurationLimits.standard
        /// Spunta «Con peso» degli esercizi a tempo (v2). A ripetizioni il peso c'è sempre.
        var withWeight: Bool = false
        /// Identità della voce (v3): le sessioni ci si legano (`SessionExercise.routineEntryID`).
        /// Facoltativa solo per la migrazione, che la riempie; le voci nuove l'hanno sempre.
        var entryID: UUID? = nil
        /// Recupero cronometro o alla rovescia (`RestMode`, v3).
        var restModeRaw: String = RestMode.stopwatch.rawValue
        /// «Parti da solo a fine recupero» (solo alla rovescia, v3).
        var autoStartAfterRest: Bool = false

        init(position: Int, exercise: Exercise?, setCount: Int = 3, repsMin: Int = 8, repsMax: Int = 12,
             approachCount: Int = 0, fixedRest: Double? = nil, setup: String = "", cues: String = "",
             measure: SetMeasure = .reps, targetSeconds: Int = DurationLimits.standard, withWeight: Bool = false,
             restMode: RestMode = .stopwatch, autoStartAfterRest: Bool = false) {
            self.entryID = UUID()
            self.restModeRaw = restMode.rawValue
            self.autoStartAfterRest = autoStartAfterRest
            self.position = position
            self.routine = nil
            self.exercise = exercise
            self.setCount = setCount
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.approachCount = approachCount
            self.fixedRest = fixedRest
            self.setup = setup
            self.cues = cues
            self.measureRaw = measure.rawValue
            self.targetSeconds = targetSeconds
            self.withWeight = withWeight
        }

        var measure: SetMeasure {
            get { SetMeasure(rawValue: measureRaw) ?? .reps }
            set { measureRaw = newValue.rawValue }
        }

        var isTimed: Bool { measure == .time }

        var restMode: RestMode {
            get { RestMode(rawValue: restModeRaw) ?? .stopwatch }
            set { restModeRaw = newValue.rawValue }
        }
    }

    /// Giorno del piano settimanale: una scheda oppure riposo (`routine == nil`).
    /// Senza nessun `PlanDay` il piano non è impostato.
    @Model
    final class PlanDay {
        /// 1 = lunedì … 7 = domenica (vedi `Weekday`).
        @Attribute(.unique) var weekday: Int
        var routine: Routine?

        init(weekday: Int, routine: Routine?) {
            self.weekday = weekday
            self.routine = routine
        }

        var isRest: Bool { routine == nil }
    }

    // MARK: Sessioni (registro)

    /// Sessione: un registro nuovo ogni volta, mai sovrascritto.
    @Model
    final class WorkoutSession {
        @Attribute(.unique) var id: UUID
        /// Scheda di partenza; `nil` per la sessione libera o se la scheda è stata eliminata.
        var routine: Routine?
        /// Nome della scheda al momento della sessione (vuoto per la sessione libera).
        var routineName: String
        var isFree: Bool
        /// Inizio: decide il giorno a cui conta la sessione, anche dopo mezzanotte.
        var startedAt: Date
        /// Fine; `nil` finché la sessione è in corso o interrotta.
        var endedAt: Date?
        /// Ultimo tocco: serve per la ripresa e per la chiusura automatica dopo 3 ore.
        var lastActivityAt: Date
        /// Chiusa da sola dopo 3 ore senza attività.
        var closedAutomatically: Bool
        /// Vero dopo «Salva sessione»: la sessione è nello storico.
        var isSaved: Bool
        var note: String

        @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
        var exercises: [SessionExercise] = []

        @Relationship(deleteRule: .cascade, inverse: \SessionPause.session)
        var pauses: [SessionPause] = []

        init(routine: Routine?, startedAt: Date = .now) {
            self.id = UUID()
            self.routine = routine
            self.routineName = routine?.name ?? ""
            self.isFree = routine == nil
            self.startedAt = startedAt
            self.endedAt = nil
            self.lastActivityAt = startedAt
            self.closedAutomatically = false
            self.isSaved = false
            self.note = ""
        }

        /// Ordine di oggi (cambia con «Rimanda» e la Scaletta, non tocca la scheda).
        var orderedExercises: [SessionExercise] {
            exercises.sorted { $0.position < $1.position }
        }

        var orderedPauses: [SessionPause] {
            pauses.sorted { $0.start < $1.start }
        }

        var isInProgress: Bool { endedAt == nil }
    }

    /// Esercizio della sessione, con i dati copiati dalla scheda.
    @Model
    final class SessionExercise {
        /// Posizione nell'ordine di oggi.
        var position: Int
        var session: WorkoutSession?
        var exercise: Exercise?
        var name: String
        var repsMin: Int
        var repsMax: Int
        var approachCount: Int
        var fixedRest: Double?
        var setup: String
        var cues: String
        /// Nota dell'esercizio per questa sessione (menu «…»).
        var note: String
        /// Tra i «Rimandati» della scaletta di oggi.
        var isPostponed: Bool
        /// Copiati dalla scheda (v2): ripetizioni o tempo, durata obiettivo, «Con peso».
        var measureRaw: String = SetMeasure.reps.rawValue
        var targetSeconds: Int = DurationLimits.standard
        var withWeight: Bool = false
        /// Voce della scheda da cui viene (v3, `RoutineEntry.entryID`); `nil` = aggiunto in sessione,
        /// sostitutivo, sessione libera.
        var routineEntryID: UUID? = nil
        /// Aggiunto alla scheda mentre la sessione era aperta: in scaletta «Aggiunto dalla scheda» (v3).
        var addedFromRoutine: Bool = false
        /// Recupero e «Parti da solo» di questo esercizio oggi (v3): copiati dalla scheda, il tocco sul tempo
        /// in sessione li cambia solo per oggi.
        var restModeRaw: String = RestMode.stopwatch.rawValue
        var autoStartAfterRest: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \SessionSet.sessionExercise)
        var sets: [SessionSet] = []

        @Relationship(deleteRule: .nullify, inverse: \SessionPause.sessionExercise)
        var pauses: [SessionPause] = []

        init(position: Int, exercise: Exercise?, name: String, repsMin: Int = 8, repsMax: Int = 12,
             approachCount: Int = 0, fixedRest: Double? = nil, setup: String = "", cues: String = "") {
            self.position = position
            self.session = nil
            self.exercise = exercise
            self.name = name
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.approachCount = approachCount
            self.fixedRest = fixedRest
            self.setup = setup
            self.cues = cues
            self.note = ""
            self.isPostponed = false
            self.measureRaw = SetMeasure.reps.rawValue
            self.targetSeconds = DurationLimits.standard
            self.withWeight = false
        }

        /// Copia un esercizio della scheda (la scheda non viene toccata).
        convenience init(position: Int, entry: RoutineEntry) {
            self.init(position: position, exercise: entry.exercise, name: entry.exercise?.name ?? "",
                      repsMin: entry.repsMin, repsMax: entry.repsMax, approachCount: entry.approachCount,
                      fixedRest: entry.fixedRest, setup: entry.setup, cues: entry.cues)
            self.measureRaw = entry.measureRaw
            self.targetSeconds = entry.targetSeconds
            self.withWeight = entry.withWeight
            self.routineEntryID = entry.entryID
            self.restModeRaw = entry.restModeRaw
            self.autoStartAfterRest = entry.autoStartAfterRest
        }

        var measure: SetMeasure {
            get { SetMeasure(rawValue: measureRaw) ?? .reps }
            set { measureRaw = newValue.rawValue }
        }

        var isTimed: Bool { measure == .time }

        var restMode: RestMode {
            get { RestMode(rawValue: restModeRaw) ?? .stopwatch }
            set { restModeRaw = newValue.rawValue }
        }

        /// Avvicinamenti prima, poi i set, nell'ordine in cui si fanno.
        var orderedSets: [SessionSet] {
            sets.sorted { $0.position < $1.position }
        }
    }

    /// Set della sessione: obiettivo e valori registrati.
    @Model
    final class SessionSet {
        var position: Int
        var sessionExercise: SessionExercise?
        var kindRaw: String
        /// Obiettivo in chili.
        var targetWeight: Double
        var targetReps: Int
        /// Valori fatti (in chili); `nil` finché il set non è fatto.
        var weight: Double?
        var reps: Int?
        /// Riserva 0…4 (4 = «4+»); `nil` se non chiesta.
        var reserveRaw: Int?
        /// Fine del 3-2-1.
        var startedAt: Date?
        /// «Set fatto»; `nil` = set non fatto.
        var endedAt: Date?
        /// Set a tempo (v2): durata obiettivo e durata fatta, in secondi; `nil` per i set a ripetizioni.
        var targetSeconds: Int? = nil
        var seconds: Int? = nil
        /// «Com'è andato?» (v3, `Feeling`); `nil` se non chiesto o per i dati vecchi (che hanno la riserva).
        var feelingRaw: String? = nil

        init(position: Int, kind: SetKind, targetWeight: Double, targetReps: Int) {
            self.position = position
            self.sessionExercise = nil
            self.kindRaw = kind.rawValue
            self.targetWeight = targetWeight
            self.targetReps = targetReps
            self.weight = nil
            self.reps = nil
            self.reserveRaw = nil
            self.startedAt = nil
            self.endedAt = nil
            self.targetSeconds = nil
            self.seconds = nil
        }

        var kind: SetKind {
            get { SetKind(rawValue: kindRaw) ?? .work }
            set { kindRaw = newValue.rawValue }
        }

        var reserve: Reserve? {
            get { reserveRaw.flatMap(Reserve.init(rawValue:)) }
            set { reserveRaw = newValue?.rawValue }
        }

        var feeling: Feeling? {
            get { feelingRaw.flatMap(Feeling.init(rawValue:)) }
            set { feelingRaw = newValue?.rawValue }
        }

        var isDone: Bool { endedAt != nil }

        /// Durata del set: dalla fine del 3-2-1 a «Set fatto».
        var setDuration: TimeInterval? {
            guard let startedAt, let endedAt else { return nil }
            return endedAt.timeIntervalSince(startedAt)
        }
    }

    /// Pausa misurata: riscaldamento, recupero o cambio esercizio.
    @Model
    final class SessionPause {
        var kindRaw: String
        var session: WorkoutSession?
        /// Per il recupero: l'esercizio del set appena fatto; per il cambio: l'esercizio che inizia.
        var sessionExercise: SessionExercise?
        /// Recupero dopo un avvicinamento: registrato ma escluso dal recupero abituale.
        var afterApproach: Bool
        var start: Date
        var end: Date

        init(kind: PauseKind, sessionExercise: SessionExercise?, afterApproach: Bool, start: Date, end: Date) {
            self.kindRaw = kind.rawValue
            self.session = nil
            self.sessionExercise = sessionExercise
            self.afterApproach = afterApproach
            self.start = start
            self.end = end
        }

        var kind: PauseKind {
            get { PauseKind(rawValue: kindRaw) ?? .rest }
            set { kindRaw = newValue.rawValue }
        }

        var duration: TimeInterval { end.timeIntervalSince(start) }
    }
}

// Nomi usati nel resto dell'app: puntano sempre alla versione corrente dello schema.
typealias Exercise = SchemaV3.Exercise
typealias Routine = SchemaV3.Routine
typealias RoutineEntry = SchemaV3.RoutineEntry
typealias PlanDay = SchemaV3.PlanDay
typealias WorkoutSession = SchemaV3.WorkoutSession
typealias SessionExercise = SchemaV3.SessionExercise
typealias SessionSet = SchemaV3.SessionSet
typealias SessionPause = SchemaV3.SessionPause
