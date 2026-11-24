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

// MARK: - Storico, esercizi

/// Lista degli esercizi dello Storico (tavola «L Esercizi»): ricerca, gruppi per scheda; ogni card
/// con il record personale a destra, sotto il nome l'ultima volta, «nuovo» se il record è recente
/// e l'avviso di stallo.
public enum ExerciseHistory {
    /// Giorni in cui un record si dice «nuovo».
    public static let newRecordDays = 14
    /// Settimane senza un record nuovo dopo le quali l'esercizio è «fermo».
    public static let stallWeeks = 3

    /// Una volta in cui l'esercizio è stato fatto: inizio della sessione e set di lavoro fatti.
    public struct Entry: Equatable, Sendable {
        public var date: Date
        public var lifts: [SessionSummary.Lift]

        public init(date: Date, lifts: [SessionSummary.Lift]) {
            self.date = date
            self.lifts = lifts
        }
    }

    /// Un esercizio con tutte le volte in cui è stato fatto.
    public struct Exercise<ID: Hashable>: Equatable {
        public var id: ID
        public var name: String
        public var entries: [Entry]

        public init(id: ID, name: String, entries: [Entry]) {
            self.id = id
            self.name = name
            self.entries = entries
        }

        /// Volte con almeno un set valido (peso e ripetizioni sopra zero), dalla più vecchia.
        var valid: [(date: Date, lifts: [SessionSummary.Lift])] {
            entries
                .map { (date: $0.date, lifts: $0.lifts.filter { $0.weight > 0 && $0.reps > 0 }) }
                .filter { !$0.lifts.isEmpty }
                .sorted { $0.date < $1.date }
        }

        /// Record personale: il set con il massimale stimato più alto (a parità, il primo) e la sua data.
        public var record: (lift: SessionSummary.Lift, date: Date)? {
            var best: (lift: SessionSummary.Lift, date: Date)?
            for entry in valid {
                for lift in entry.lifts where lift.estimatedMax > (best?.lift.estimatedMax ?? 0) + 0.001 {
                    best = (lift, entry.date)
                }
            }
            return best
        }

        /// Ultima volta: il set più pesante (a parità di peso, più ripetizioni) e la data.
        public var last: (lift: SessionSummary.Lift, date: Date)? {
            guard let entry = valid.last,
                  let lift = entry.lifts.max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) }) else { return nil }
            return (lift, entry.date)
        }

        /// «nuovo»: record fatto negli ultimi 14 giorni che ha superato una volta precedente
        /// (la prima volta non è un record nuovo).
        public func isNewRecord(today: Date, calendar: Calendar = .current) -> Bool {
            guard let record, let first = valid.first, first.date < record.date else { return false }
            return days(from: record.date, to: today, calendar: calendar) < newRecordDays
        }

        /// Settimane senza un record nuovo, se l'esercizio è fermo: fatto anche dopo il record e
        /// record più vecchio di 3 settimane. `nil` se non è fermo.
        public func stalledWeeks(today: Date, calendar: Calendar = .current) -> Int? {
            guard let record, let last, last.date > record.date else { return nil }
            let weeks = days(from: record.date, to: today, calendar: calendar) / 7
            return weeks >= stallWeeks ? weeks : nil
        }
    }

    static func days(from start: Date, to end: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
    }

    /// Gruppo della lista: una scheda (o «Altri esercizi»).
    public struct Group<ID: Hashable>: Equatable {
        public var title: String
        /// «5 esercizi».
        public var count: String
        public var exercises: [Exercise<ID>]
    }

    /// Nome del gruppo con gli esercizi fatti che non sono in nessuna scheda.
    public static let otherTitle = "Altri esercizi"

    /// Gruppi per scheda (nell'ordine delle schede, esercizi nell'ordine della scheda; un esercizio in
    /// più schede compare in ognuna), poi «Altri esercizi» in ordine alfabetico. Solo esercizi con
    /// almeno un set valido che corrispondono alla ricerca; gruppi vuoti tolti.
    public static func groups<ID: Hashable>(
        exercises: [Exercise<ID>],
        routines: [(name: String, exercises: [ID])],
        query: String
    ) -> [Group<ID>] {
        let done = exercises.filter { !$0.valid.isEmpty && LibrarySearch.matches($0.name, query: query) }
        let byID = Dictionary(done.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var inRoutine = Set<ID>()
        var result: [Group<ID>] = []
        for routine in routines {
            var seen = Set<ID>()
            let items = routine.exercises.compactMap { id -> Exercise<ID>? in
                guard seen.insert(id).inserted else { return nil }
                return byID[id]
            }
            inRoutine.formUnion(routine.exercises)
            if !items.isEmpty {
                result.append(Group(title: routine.name, count: count(items.count), exercises: items))
            }
        }
        let others = done.filter { !inRoutine.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if !others.isEmpty {
            result.append(Group(title: otherTitle, count: count(others.count), exercises: others))
        }
        return result
    }

    /// «1 esercizio», «5 esercizi».
    public static func count(_ value: Int) -> String {
        value == 1 ? "1 esercizio" : "\(value) esercizi"
    }

    /// «Ultima: 62,5 × 9, gio 19»; fuori dal mese di oggi «Ultima: 62,5 × 9, gio 19 ott».
    public static func lastText(_ lift: SessionSummary.Lift, date: Date, today: Date, calendar: Calendar = .current) -> String {
        "Ultima: \(SessionText.weightReps(lift.weight, lift.reps)), \(shortDate(date, today: today, calendar: calendar))"
    }

    /// «gio 19», con il mese corto («gio 19 ott») se non è il mese di oggi.
    public static func shortDate(_ date: Date, today: Date, calendar: Calendar = .current) -> String {
        let weekday = SessionHistory.weekdayShort(Weekday.of(date, calendar: calendar)).lowercased()
        let day = calendar.component(.day, from: date)
        let sameMonth = calendar.isDate(date, equalTo: today, toGranularity: .month)
        if sameMonth { return "\(weekday) \(day)" }
        let month = ItalianDate.months[max(0, min(11, calendar.component(.month, from: date) - 1))]
        return "\(weekday) \(day) \(month.prefix(3))"
    }

    /// «fermo da 3 settimane».
    public static func stallText(weeks: Int) -> String {
        "fermo da \(weeks) settimane"
    }
}
