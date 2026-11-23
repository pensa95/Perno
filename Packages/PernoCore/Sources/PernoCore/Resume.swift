import Foundation

/// Avanzamento di un esercizio nella card della sessione interrotta (set di lavoro).
public struct ExerciseProgress: Equatable, Sendable {
    public var name: String
    public var done: Int
    public var total: Int

    public init(name: String, done: Int, total: Int) {
        self.name = name
        self.done = done
        self.total = total
    }

    public enum State: Equatable, Sendable { case done, started, notStarted }

    public var state: State {
        if total > 0 && done >= total { return .done }
        return done > 0 ? .started : .notStarted
    }
}

/// Testi della card «Sessione interrotta» / «Sessione in corso» e della barra ridotta.
public enum ResumeText {
    /// «18:24».
    public static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = parts.minute ?? 0
        return "\(parts.hour ?? 0):\(minute < 10 ? "0" : "")\(minute)"
    }

    /// «L'app si è chiusa alle 18:24. Avevi fatto 7 set su 14; tutto è salvato fino all'ultimo «Set fatto».»
    public static func interrupted(at date: Date, done: Int, total: Int, calendar: Calendar = .current) -> String {
        "L'app si è chiusa alle \(time(date, calendar: calendar)). Avevi fatto \(done) set su \(total); "
            + "tutto è salvato fino all'ultimo «Set fatto»."
    }

    /// «Hai fatto 7 set su 14.»
    public static func inProgress(done: Int, total: Int) -> String {
        "Hai fatto \(done) set su \(total)."
    }

    /// «Chest press fatto, Lat machine 1 di 3, poi Shoulder press»: gli esercizi fatti o iniziati,
    /// poi il primo da fare.
    public static func summary(_ exercises: [ExerciseProgress]) -> String {
        var parts: [String] = []
        for exercise in exercises {
            switch exercise.state {
            case .done:
                parts.append("\(exercise.name) fatto")
            case .started:
                parts.append("\(exercise.name) \(exercise.done) di \(exercise.total)")
            case .notStarted:
                parts.append(parts.isEmpty ? "Da iniziare: \(exercise.name)" : "poi \(exercise.name)")
                return parts.joined(separator: ", ")
            }
        }
        return parts.joined(separator: ", ")
    }

    /// Nota sotto la card della sessione interrotta.
    public static let footnote = "Riprendendo entro 3 ore la sessione continua dal set dopo l'ultimo fatto, "
        + "con il recupero ricalcolato da adesso. Dopo 3 ore si chiude da sola."
}
