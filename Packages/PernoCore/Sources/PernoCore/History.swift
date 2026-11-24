import Foundation

// MARK: - Storico, sessioni

/// Lista delle sessioni dello Storico: una lista sola, mese come intestazione fissa, settimana come
/// separatore con il conteggio, giorno a sinistra con più sessioni impilate. Dalla più recente.
public enum SessionHistory {
    /// Sessione chiusa, come serve alla lista.
    public struct Item<ID: Hashable>: Equatable {
        public var id: ID
        public var start: Date
        public var title: String
        public var duration: TimeInterval
        /// Set di lavoro fatti (avvicinamenti esclusi).
        public var sets: Int
        /// Sessione libera: nella riga gli esercizi al posto dei set.
        public var isFree: Bool
        /// Esercizi con almeno un set fatto.
        public var exercises: Int
        /// Coppa: almeno un record nella sessione.
        public var hasRecord: Bool

        public init(id: ID, start: Date, title: String, duration: TimeInterval, sets: Int,
                    isFree: Bool = false, exercises: Int = 0, hasRecord: Bool = false) {
            self.id = id
            self.start = start
            self.title = title
            self.duration = duration
            self.sets = sets
            self.isFree = isFree
            self.exercises = exercises
            self.hasRecord = hasRecord
        }

        /// «58 min · 14 set»; per la sessione libera «22 min · 2 esercizi».
        public var subtitle: String {
            let minutes = SessionSummary.minutes(duration)
            if isFree {
                return "\(minutes) · \(exercises == 1 ? "1 esercizio" : "\(exercises) esercizi")"
            }
            return "\(minutes) · \(sets) set"
        }
    }

    public struct Day<ID: Hashable>: Equatable {
        public var date: Date
        /// «LUN».
        public var weekday: String
        /// «16».
        public var number: String
        /// In ordine di inizio.
        public var items: [Item<ID>]
    }

    public struct Week<ID: Hashable>: Equatable {
        /// Lunedì della settimana.
        public var start: Date
        /// «16 – 22 novembre», «26 ott – 1 nov».
        public var label: String
        /// «1 sessione», «5 sessioni».
        public var count: String
        /// Dal più recente.
        public var days: [Day<ID>]
    }

    public struct Month<ID: Hashable>: Equatable {
        public var year: Int
        public var month: Int
        /// «Novembre 2026».
        public var title: String
        /// «11 sessioni».
        public var count: String
        /// Dalla più recente.
        public var weeks: [Week<ID>]
    }

    /// Anni con almeno una sessione, dal più recente.
    public static func years<ID: Hashable>(_ items: [Item<ID>], calendar: Calendar = .current) -> [Int] {
        Array(Set(items.map { calendar.component(.year, from: $0.start) })).sorted(by: >)
    }

    /// Anno mostrato all'apertura: il più recente con sessioni, altrimenti l'anno di `today`.
    public static func defaultYear<ID: Hashable>(_ items: [Item<ID>], today: Date, calendar: Calendar = .current) -> Int {
        years(items, calendar: calendar).first ?? calendar.component(.year, from: today)
    }

    /// Mesi dell'anno scelto. Una settimana a cavallo di due mesi compare in tutti e due,
    /// ciascuna con le sole sessioni di quel mese.
    public static func months<ID: Hashable>(_ items: [Item<ID>], year: Int, calendar: Calendar = .current) -> [Month<ID>] {
        let ofYear = items.filter { calendar.component(.year, from: $0.start) == year }
        let byMonth = Dictionary(grouping: ofYear) { calendar.component(.month, from: $0.start) }
        return byMonth.keys.sorted(by: >).map { month in
            let monthItems = byMonth[month] ?? []
            let byWeek = Dictionary(grouping: monthItems) { WeekCalendar.weekStart(of: $0.start, calendar: calendar) }
            let weeks = byWeek.keys.sorted(by: >).map { start -> Week<ID> in
                let weekItems = byWeek[start] ?? []
                let byDay = Dictionary(grouping: weekItems) { calendar.startOfDay(for: $0.start) }
                let days = byDay.keys.sorted(by: >).map { day -> Day<ID> in
                    Day(date: day,
                        weekday: weekdayShort(Weekday.of(day, calendar: calendar)),
                        number: String(calendar.component(.day, from: day)),
                        items: (byDay[day] ?? []).sorted { $0.start < $1.start })
                }
                return Week(start: start, label: weekLabel(start, calendar: calendar),
                            count: sessions(weekItems.count), days: days)
            }
            return Month(year: year, month: month, title: monthTitle(month, year: year),
                         count: sessions(monthItems.count), weeks: weeks)
        }
    }

    // MARK: Testi

    /// «1 sessione», «5 sessioni».
    public static func sessions(_ count: Int) -> String {
        count == 1 ? "1 sessione" : "\(count) sessioni"
    }

    /// «Novembre 2026».
    public static func monthTitle(_ month: Int, year: Int) -> String {
        let name = ItalianDate.months[max(0, min(11, month - 1))]
        let capitalized = name.prefix(1).uppercased() + String(name.dropFirst())
        return "\(capitalized) \(year)"
    }

    /// «LUN» … «DOM».
    public static func weekdayShort(_ weekday: Int) -> String {
        String(Weekday.name(weekday).prefix(3)).uppercased()
    }

    /// Da lunedì a domenica: «16 – 22 novembre»; a cavallo di due mesi «26 ott – 1 nov».
    public static func weekLabel(_ monday: Date, calendar: Calendar = .current) -> String {
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let first = calendar.dateComponents([.day, .month], from: monday)
        let last = calendar.dateComponents([.day, .month], from: sunday)
        let firstMonth = ItalianDate.months[max(0, min(11, (first.month ?? 1) - 1))]
        let lastMonth = ItalianDate.months[max(0, min(11, (last.month ?? 1) - 1))]
        if first.month == last.month {
            return "\(first.day ?? 1) – \(last.day ?? 1) \(lastMonth)"
        }
        return "\(first.day ?? 1) \(firstMonth.prefix(3)) – \(last.day ?? 1) \(lastMonth.prefix(3))"
    }
}

// MARK: - Dettaglio sessione

/// Testi del dettaglio sessione (tavola «L Dettaglio sessione»).
public enum SessionDetailText {
    /// «Giovedì 19 novembre, dalle 18:04 alle 19:03».
    public static func when(start: Date, end: Date, calendar: Calendar = .current) -> String {
        "\(ItalianDate.long(start, calendar: calendar)), dalle \(ResumeText.time(start, calendar: calendar)) alle \(ResumeText.time(end, calendar: calendar))"
    }

    /// Avvicinamenti fatti (pesi in chili): «Avvicinamento 30 × 10, 45 × 6»; senza «Avvicinamento —».
    public static func approaches(_ sets: [(weight: Double, reps: Int)]) -> String {
        guard !sets.isEmpty else { return "Avvicinamento —" }
        return "Avvicinamento " + sets.map { SessionText.weightReps($0.weight, $0.reps) }.joined(separator: ", ")
    }

    /// «riserva 1», «riserva 4+»; `nil` se la riserva non è stata data.
    public static func reserve(_ reserve: Reserve?) -> String? {
        reserve.map { "riserva \($0.label)" }
    }

    /// Set di lavoro non fatto.
    public static let notDone = "non fatto"
}
