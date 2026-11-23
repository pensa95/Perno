import Foundation

/// Chiusura automatica: dopo 3 ore senza attività la sessione si chiude all'ultimo «Set fatto».
public enum AutoClose {
    public static let threshold: TimeInterval = 3 * 3600

    /// Vero se dall'ultimo tocco sono passate almeno 3 ore.
    public static func isDue(lastActivity: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastActivity) >= threshold
    }

    /// Fine della sessione chiusa da sola: l'ultimo «Set fatto»; senza set, l'ultimo tocco.
    public static func end(lastSetEnd: Date?, lastActivity: Date) -> Date {
        lastSetEnd ?? lastActivity
    }

    /// «Nessuna attività per 3 ore. La durata finisce all'ultimo set, alle 19:42.»
    public static func message(end: Date, hadSets: Bool, calendar: Calendar = .current) -> String {
        let time = ResumeText.time(end, calendar: calendar)
        return hadSets
            ? "Nessuna attività per 3 ore. La durata finisce all'ultimo set, alle \(time)."
            : "Nessuna attività per 3 ore. La durata finisce all'ultimo tocco, alle \(time)."
    }
}

/// Date in italiano.
public enum ItalianDate {
    static let months = ["gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio",
                         "agosto", "settembre", "ottobre", "novembre", "dicembre"]

    /// «Sabato 21 novembre».
    public static func long(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        let weekday = Weekday.name(Weekday.of(date, calendar: calendar))
        let month = months[max(0, min(11, (parts.month ?? 1) - 1))]
        return "\(weekday) \(parts.day ?? 1) \(month)"
    }
}
