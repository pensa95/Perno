import Foundation

// MARK: - File di backup

/// Contenuto di un backup: tutti i dati dell'app, in JSON. I pesi sono in chili, gli enum come
/// valore grezzo (come nel database). I legami tra oggetti passano dagli `id`.
public struct BackupFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var createdAt: Date
    public var exercises: [Exercise]
    public var routines: [Routine]
    public var planDays: [PlanDay]
    public var sessions: [Session]

    public init(version: Int = BackupFile.currentVersion, createdAt: Date, exercises: [Exercise],
                routines: [Routine], planDays: [PlanDay], sessions: [Session]) {
        self.version = version
        self.createdAt = createdAt
        self.exercises = exercises
        self.routines = routines
        self.planDays = planDays
        self.sessions = sessions
    }

    public struct Exercise: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var muscleGroup: String
        public var equipment: String
        public var type: String
        public var builtInKey: String?
        public var createdAt: Date

        public init(id: UUID, name: String, muscleGroup: String, equipment: String, type: String,
                    builtInKey: String?, createdAt: Date) {
            self.id = id
            self.name = name
            self.muscleGroup = muscleGroup
            self.equipment = equipment
            self.type = type
            self.builtInKey = builtInKey
            self.createdAt = createdAt
        }
    }

    public struct Routine: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var createdAt: Date
        public var entries: [Entry]

        public init(id: UUID, name: String, createdAt: Date, entries: [Entry]) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.entries = entries
        }
    }

    public struct Entry: Codable, Equatable, Sendable {
        public var position: Int
        public var exerciseID: UUID?
        public var setCount: Int
        public var repsMin: Int
        public var repsMax: Int
        public var approachCount: Int
        public var fixedRest: Double?
        public var setup: String
        public var cues: String
        /// Esercizi a tempo (v5); assenti nei backup precedenti = a ripetizioni.
        public var measure: String?
        public var targetSeconds: Int?
        public var withWeight: Bool?
        /// UI v6 (SchemaV3); assenti nei backup precedenti: `id` della voce (legame con le sessioni),
        /// recupero cronometro / alla rovescia e «Parti da solo a fine recupero».
        public var id: UUID?
        public var restMode: String?
        public var autoStartAfterRest: Bool?

        public init(position: Int, exerciseID: UUID?, setCount: Int, repsMin: Int, repsMax: Int,
                    approachCount: Int, fixedRest: Double?, setup: String, cues: String,
                    measure: String? = nil, targetSeconds: Int? = nil, withWeight: Bool? = nil,
                    id: UUID? = nil, restMode: String? = nil, autoStartAfterRest: Bool? = nil) {
            self.id = id
            self.restMode = restMode
            self.autoStartAfterRest = autoStartAfterRest
            self.position = position
            self.exerciseID = exerciseID
            self.setCount = setCount
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.approachCount = approachCount
            self.fixedRest = fixedRest
            self.setup = setup
            self.cues = cues
            self.measure = measure
            self.targetSeconds = targetSeconds
            self.withWeight = withWeight
        }
    }

    public struct PlanDay: Codable, Equatable, Sendable {
        public var weekday: Int
        public var routineID: UUID?

        public init(weekday: Int, routineID: UUID?) {
            self.weekday = weekday
            self.routineID = routineID
        }
    }

    public struct Session: Codable, Equatable, Sendable {
        public var id: UUID
        public var routineID: UUID?
        public var routineName: String
        public var isFree: Bool
        public var startedAt: Date
        public var endedAt: Date?
        public var lastActivityAt: Date
        public var closedAutomatically: Bool
        public var isSaved: Bool
        public var note: String
        public var exercises: [SessionExercise]
        public var pauses: [Pause]

        public init(id: UUID, routineID: UUID?, routineName: String, isFree: Bool, startedAt: Date,
                    endedAt: Date?, lastActivityAt: Date, closedAutomatically: Bool, isSaved: Bool,
                    note: String, exercises: [SessionExercise], pauses: [Pause]) {
            self.id = id
            self.routineID = routineID
            self.routineName = routineName
            self.isFree = isFree
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.lastActivityAt = lastActivityAt
            self.closedAutomatically = closedAutomatically
            self.isSaved = isSaved
            self.note = note
            self.exercises = exercises
            self.pauses = pauses
        }
    }

    public struct SessionExercise: Codable, Equatable, Sendable {
        public var position: Int
        public var exerciseID: UUID?
        public var name: String
        public var repsMin: Int
        public var repsMax: Int
        public var approachCount: Int
        public var fixedRest: Double?
        public var setup: String
        public var cues: String
        public var note: String
        public var isPostponed: Bool
        public var sets: [SessionSet]
        /// Esercizi a tempo (v5); assenti nei backup precedenti = a ripetizioni.
        public var measure: String?
        public var targetSeconds: Int?
        public var withWeight: Bool?
        /// UI v6 (SchemaV3); assenti nei backup precedenti: voce della scheda da cui viene (`nil` = aggiunto
        /// in sessione), «Aggiunto dalla scheda», recupero e «Parti da solo» di oggi.
        public var routineEntryID: UUID?
        public var addedFromRoutine: Bool?
        public var restMode: String?
        public var autoStartAfterRest: Bool?

        public init(position: Int, exerciseID: UUID?, name: String, repsMin: Int, repsMax: Int,
                    approachCount: Int, fixedRest: Double?, setup: String, cues: String, note: String,
                    isPostponed: Bool, sets: [SessionSet],
                    measure: String? = nil, targetSeconds: Int? = nil, withWeight: Bool? = nil,
                    routineEntryID: UUID? = nil, addedFromRoutine: Bool? = nil, restMode: String? = nil,
                    autoStartAfterRest: Bool? = nil) {
            self.routineEntryID = routineEntryID
            self.addedFromRoutine = addedFromRoutine
            self.restMode = restMode
            self.autoStartAfterRest = autoStartAfterRest
            self.position = position
            self.exerciseID = exerciseID
            self.name = name
            self.repsMin = repsMin
            self.repsMax = repsMax
            self.approachCount = approachCount
            self.fixedRest = fixedRest
            self.setup = setup
            self.cues = cues
            self.note = note
            self.isPostponed = isPostponed
            self.sets = sets
            self.measure = measure
            self.targetSeconds = targetSeconds
            self.withWeight = withWeight
        }
    }

    public struct SessionSet: Codable, Equatable, Sendable {
        public var position: Int
        public var kind: String
        public var targetWeight: Double
        public var targetReps: Int
        public var weight: Double?
        public var reps: Int?
        public var reserve: Int?
        public var startedAt: Date?
        public var endedAt: Date?
        /// Set a tempo (v5): durata obiettivo e fatta, in secondi.
        public var targetSeconds: Int?
        public var seconds: Int?
        /// «Com'è andato?» (UI v6, `Feeling`); assente nei backup precedenti.
        public var feeling: String?

        public init(position: Int, kind: String, targetWeight: Double, targetReps: Int, weight: Double?,
                    reps: Int?, reserve: Int?, startedAt: Date?, endedAt: Date?,
                    targetSeconds: Int? = nil, seconds: Int? = nil, feeling: String? = nil) {
            self.feeling = feeling
            self.position = position
            self.kind = kind
            self.targetWeight = targetWeight
            self.targetReps = targetReps
            self.weight = weight
            self.reps = reps
            self.reserve = reserve
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.targetSeconds = targetSeconds
            self.seconds = seconds
        }
    }

    public struct Pause: Codable, Equatable, Sendable {
        public var kind: String
        /// Posizione (nell'ordine di oggi) dell'esercizio della pausa; `nil` per il riscaldamento.
        public var exercisePosition: Int?
        public var afterApproach: Bool
        public var start: Date
        public var end: Date

        public init(kind: String, exercisePosition: Int?, afterApproach: Bool, start: Date, end: Date) {
            self.kind = kind
            self.exercisePosition = exercisePosition
            self.afterApproach = afterApproach
            self.start = start
            self.end = end
        }
    }

    // MARK: JSON

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Legge un backup; rifiuta versioni più nuove di quella che l'app conosce.
    public static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)
        guard file.version <= currentVersion else { throw BackupError.newerVersion }
        return file
    }

    /// Sessioni chiuse (quelle che contano nello storico).
    public var finishedSessionCount: Int { sessions.filter { $0.endedAt != nil }.count }
}

public enum BackupError: Error, Equatable {
    case newerVersion
}

// MARK: - Nomi dei file e copie da tenere

public enum BackupFiles {
    public static let prefix = "perno-"
    public static let suffix = ".json"
    public static let keepChoices = [3, 5, 10]
    public static let defaultKeep = 3

    /// «perno-2026-11-24-180212.json»: data e ora locali, ordinabili per nome.
    public static func name(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        func two(_ value: Int?) -> String { String(format: "%02d", value ?? 0) }
        return "\(prefix)\(parts.year ?? 0)-\(two(parts.month))-\(two(parts.day))-"
            + "\(two(parts.hour))\(two(parts.minute))\(two(parts.second))\(suffix)"
    }

    /// Data scritta nel nome del file; `nil` se il file non è un backup di Perno.
    public static func date(fromName name: String, calendar: Calendar = .current) -> Date? {
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let core = name.dropFirst(prefix.count).dropLast(suffix.count)
        let pieces = core.split(separator: "-")
        guard pieces.count == 4, pieces[3].count == 6,
              let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]),
              let time = Int(pieces[3]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = time / 10_000
        components.minute = (time / 100) % 100
        components.second = time % 100
        return calendar.date(from: components)
    }

    /// Backup di Perno tra i nomi dati, dal più recente.
    public static func backups(in names: [String]) -> [String] {
        names.filter { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) }.sorted(by: >)
    }

    /// Copie da cancellare per tenerne `keep`, le più vecchie (si cancella solo dopo aver scritto).
    public static func toDelete(from names: [String], keep: Int) -> [String] {
        Array(backups(in: names).dropFirst(max(1, keep)))
    }
}

// MARK: - Testi

public enum BackupText {
    /// «16 novembre».
    public static func dayMonth(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        let month = ItalianDate.months[(parts.month ?? 1) - 1]
        return "\(parts.day ?? 1) \(month)"
    }

    /// «oggi alle 18:02», «ieri alle 9:15», «il 19 novembre alle 18:02».
    public static func when(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = ResumeText.time(date, calendar: calendar)
        if calendar.isDate(date, inSameDayAs: now) { return "oggi alle \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "ieri alle \(time)" }
        return "il \(dayMonth(date, calendar: calendar)) alle \(time)"
    }

    /// «Ultimo backup oggi alle 18:02».
    public static func lastBackup(_ date: Date, now: Date, calendar: Calendar = .current) -> String {
        "Ultimo backup \(when(date, now: now, calendar: calendar))"
    }

    /// «Dopo la sessione Upper body. 3 copie nella cartella, la più vecchia del 16 novembre».
    public static func detail(afterSession name: String?, copies: Int, oldest: Date?,
                              calendar: Calendar = .current) -> String {
        var parts: [String] = []
        if let name, !name.isEmpty { parts.append("Dopo la sessione \(name).") }
        if copies == 1 {
            parts.append("1 copia nella cartella")
        } else if copies > 1 {
            var text = "\(copies) copie nella cartella"
            if let oldest { text += ", la più vecchia del \(dayMonth(oldest, calendar: calendar))" }
            parts.append(text)
        }
        return parts.joined(separator: " ")
    }

    /// Avviso in Home: «L'app non può più scrivere nella cartella Palestra, …».
    public static func failure(folder: String, lastSuccess: Date?, calendar: Calendar = .current) -> String {
        var text = "L'app non può più scrivere nella cartella \(folder), di solito dopo un rinnovo dell'app."
        if let lastSuccess {
            text += " L'ultima copia è del \(dayMonth(lastSuccess, calendar: calendar)); i dati sul telefono sono al sicuro."
        } else {
            text += " I dati sul telefono sono al sicuro."
        }
        return text
    }

    /// Dove si trova la cartella: «iCloud Drive» o «Sul mio iPhone».
    public static func location(path: String) -> String {
        path.contains("Mobile Documents") ? "iCloud Drive" : "Sul mio iPhone"
    }

    /// Voce delle Impostazioni: «iCloud Drive, cartella Palestra, ultimo oggi alle 18:02».
    public static func settingsSummary(location: String?, folder: String?, last: Date?, failed: Bool,
                                       now: Date, calendar: Calendar = .current) -> String {
        guard let location, let folder else { return "Nessuna cartella scelta" }
        if failed { return "\(location), cartella \(folder), backup non riuscito" }
        guard let last else { return "\(location), cartella \(folder)" }
        return "\(location), cartella \(folder), ultimo \(when(last, now: now, calendar: calendar))"
    }

    /// Riepilogo di un backup da ripristinare: «24 sessioni, 2 schede, 47 esercizi».
    public static func contents(_ file: BackupFile) -> String {
        func count(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? "1 \(one)" : "\(n) \(many)" }
        return [count(file.finishedSessionCount, "sessione", "sessioni"),
                count(file.routines.count, "scheda", "schede"),
                count(file.exercises.count, "esercizio", "esercizi")].joined(separator: ", ")
    }
}

// MARK: - Primo avvio

public enum FirstRun {
    /// Il primo avvio si mostra solo a un'app vuota (niente schede né sessioni): chi aveva già
    /// dati prima di questa versione non lo vede.
    public static func shouldShow(done: Bool, hasRoutines: Bool, hasSessions: Bool) -> Bool {
        !done && !hasRoutines && !hasSessions
    }
}

extension BackupText {
    /// «Nella cartella Palestra c'è una copia dei tuoi dati.»
    public static func found(folder: String) -> String {
        "Nella cartella \(folder) c'è una copia dei tuoi dati."
    }

    /// «Giovedì 19 novembre, 18:02».
    public static func copyDate(_ date: Date, calendar: Calendar = .current) -> String {
        "\(ItalianDate.long(date, calendar: calendar)), \(ResumeText.time(date, calendar: calendar))"
    }

    /// «Ce ne sono altre 2, la più vecchia del 16 novembre»; `nil` senza altre copie.
    public static func otherCopies(_ count: Int, oldest: Date?, calendar: Calendar = .current) -> String? {
        guard count > 0 else { return nil }
        guard let oldest else { return count == 1 ? "Ce n'è un'altra" : "Ce ne sono altre \(count)" }
        let day = dayMonth(oldest, calendar: calendar)
        return count == 1 ? "Ce n'è un'altra, del \(day)" : "Ce ne sono altre \(count), la più vecchia del \(day)"
    }
}
