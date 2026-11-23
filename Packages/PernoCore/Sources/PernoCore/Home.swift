import Foundation

// Logica della Home: calendario della settimana, scheda di oggi, prossimo allenamento, testi.

/// Stato di un giorno nel calendario della settimana.
public enum DayStatus: Equatable, Sendable {
    /// Spunta: quel giorno c'è una sessione con la scheda in programma (o una sessione in un giorno di riposo).
    case done
    /// Bordo pieno: giorno passato in programma senza sessione.
    case skipped
    /// Tratteggio: oggi o più avanti, in programma.
    case planned
    /// Puntino: riposo.
    case rest
}

public struct CalendarDay: Equatable, Sendable {
    /// 1 = lunedì … 7 = domenica.
    public var weekday: Int
    public var date: Date
    public var status: DayStatus
    /// Nome corto sotto il giorno («Upper»); vuoto per il riposo.
    public var label: String
    public var isToday: Bool
}

/// Sessione finita, per il calendario e la scheda di oggi.
public struct FinishedSession<ID: Hashable> {
    public var start: Date
    /// Scheda di partenza; `nil` per la sessione libera.
    public var routine: ID?
    public var name: String

    public init(start: Date, routine: ID?, name: String) {
        self.start = start
        self.routine = routine
        self.name = name
    }
}

public enum WeekCalendar {
    /// Iniziale del giorno: L M M G V S D.
    public static func letter(_ weekday: Int) -> String {
        String(Weekday.name(weekday).prefix(1))
    }

    /// Mezzanotte del lunedì della settimana di `date`.
    public static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = Weekday.of(date, calendar: calendar) - 1
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    /// Nome corto: la prima parola («Upper body» → «Upper»); «Libera» per la sessione libera.
    public static func shortName(_ name: String) -> String {
        let first = name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "Libera" : first
    }

    /// I sette giorni della settimana di `today`.
    /// `plan`: scheda per giorno (solo i giorni con una scheda); `names`: nome di ogni scheda.
    /// Una sessione conta per il giorno in cui è iniziata.
    public static func days<ID: Hashable>(
        today: Date,
        plan: [Int: ID],
        names: [ID: String],
        sessions: [FinishedSession<ID>],
        calendar: Calendar
    ) -> [CalendarDay] {
        let start = weekStart(of: today, calendar: calendar)
        let todayStart = calendar.startOfDay(for: today)
        return Weekday.all.map { weekday in
            let date = calendar.date(byAdding: .day, value: weekday - 1, to: start) ?? start
            let thatDay = sessions.filter { calendar.isDate($0.start, inSameDayAs: date) }
            let isToday = calendar.isDate(date, inSameDayAs: today)
            if let planned = plan[weekday] {
                let label = shortName(names[planned] ?? "")
                let status: DayStatus
                if thatDay.contains(where: { $0.routine == planned }) {
                    status = .done
                } else if date < todayStart {
                    status = .skipped
                } else {
                    status = .planned
                }
                return CalendarDay(weekday: weekday, date: date, status: status, label: label, isToday: isToday)
            }
            if let session = thatDay.first {
                return CalendarDay(weekday: weekday, date: date, status: .done,
                                   label: shortName(session.name), isToday: isToday)
            }
            return CalendarDay(weekday: weekday, date: date, status: .rest, label: "", isToday: isToday)
        }
    }
}

public enum TodayPlan {
    /// Scheda proposta oggi. Con il piano impostato: quella del giorno (`nil` nei giorni di riposo).
    /// Senza piano: la scheda fatta meno di recente (prima quelle mai fatte, nell'ordine dato).
    public static func proposal<ID: Hashable>(
        weekday: Int,
        plan: [Int: ID],
        planIsSet: Bool,
        routines: [ID],
        lastDone: [ID: Date]
    ) -> ID? {
        if planIsSet { return plan[weekday] }
        var best: (id: ID, date: Date)?
        for id in routines {
            let date = lastDone[id] ?? .distantPast
            if best == nil || date < best!.date { best = (id, date) }
        }
        return best?.id
    }

    /// Prossimo giorno in programma dopo oggi (anche la settimana dopo): giorno e scheda.
    public static func next<ID: Hashable>(after weekday: Int, plan: [Int: ID]) -> (weekday: Int, routine: ID)? {
        for step in 1...7 {
            let day = (weekday - 1 + step) % 7 + 1
            if let routine = plan[day] { return (day, routine) }
        }
        return nil
    }
}

public enum HomeText {
    /// «Chest press, Lat machine, Shoulder press e altri 2, circa 55 minuti».
    public static func exercises(_ names: [String], minutes: Int) -> String {
        guard !names.isEmpty else { return "Nessun esercizio" }
        let list: String
        switch names.count {
        case 1:
            list = names[0]
        case 2, 3:
            list = names.dropLast().joined(separator: ", ") + " e " + names[names.count - 1]
        default:
            let others = names.count - 3
            list = names.prefix(3).joined(separator: ", ") + (others == 1 ? " e un altro" : " e altri \(others)")
        }
        return "\(list), circa \(minutes) minuti"
    }

    /// Durata lunga: «58:40», «1:05:20».
    public static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        func two(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
        return hours > 0 ? "\(hours):\(two(minutes)):\(two(secs))" : "\(minutes):\(two(secs))"
    }

    /// Chili sollevati con il punto delle migliaia: «6.240».
    public static func volume(_ kilograms: Double) -> String {
        let digits = String(max(0, Int(kilograms.rounded())))
        var result = ""
        for (index, char) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { result.append(".") }
            result.append(char)
        }
        return result
    }

    /// Chili sollevati: peso × ripetizioni dei set fatti, avvicinamenti esclusi.
    public static func liftedKilograms(_ sets: [(kind: SetKind, weight: Double, reps: Int)]) -> Double {
        sets.filter { $0.kind != .approach }.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
}
