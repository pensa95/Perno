import XCTest
@testable import PernoCore

final class HistoryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 18) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        return calendar.date(from: parts)!
    }

    private func item(_ id: Int, _ start: Date, _ title: String = "Upper body", free: Bool = false) -> SessionHistory.Item<Int> {
        SessionHistory.Item(id: id, start: start, title: title, duration: 58 * 60, sets: 14,
                            isFree: free, exercises: 2)
    }

    func testTexts() {
        XCTAssertEqual(SessionHistory.sessions(1), "1 sessione")
        XCTAssertEqual(SessionHistory.sessions(5), "5 sessioni")
        XCTAssertEqual(SessionHistory.monthTitle(11, year: 2026), "Novembre 2026")
        XCTAssertEqual(SessionHistory.weekdayShort(1), "LUN")
        XCTAssertEqual(SessionHistory.weekdayShort(4), "GIO")
        XCTAssertEqual(SessionHistory.weekdayShort(7), "DOM")
        // 16 novembre 2026 è lunedì.
        XCTAssertEqual(SessionHistory.weekLabel(date(2026, 11, 16, 0), calendar: calendar), "16 – 22 novembre")
        XCTAssertEqual(SessionHistory.weekLabel(date(2026, 10, 26, 0), calendar: calendar), "26 ott – 1 nov")
    }

    func testSubtitle() {
        XCTAssertEqual(item(1, date(2026, 11, 16)).subtitle, "58 min · 14 set")
        var free = item(2, date(2026, 11, 12), "Sessione libera", free: true)
        free.duration = 22 * 60
        XCTAssertEqual(free.subtitle, "22 min · 2 esercizi")
        free.exercises = 1
        XCTAssertEqual(free.subtitle, "22 min · 1 esercizio")
    }

    func testGrouping() {
        let items = [
            item(1, date(2026, 11, 12, 18)),
            item(2, date(2026, 11, 16)),
            item(3, date(2026, 11, 12, 9), "Sessione libera", free: true),
            item(4, date(2026, 11, 1)),   // domenica: settimana 26 ott – 1 nov
            item(5, date(2026, 10, 27)),
            item(6, date(2025, 12, 30)),
        ]
        XCTAssertEqual(SessionHistory.years(items, calendar: calendar), [2026, 2025])
        XCTAssertEqual(SessionHistory.defaultYear(items, today: date(2027, 1, 2), calendar: calendar), 2026)
        XCTAssertEqual(SessionHistory.defaultYear([SessionHistory.Item<Int>](), today: date(2027, 1, 2), calendar: calendar), 2027)

        let months = SessionHistory.months(items, year: 2026, calendar: calendar)
        XCTAssertEqual(months.map(\.title), ["Novembre 2026", "Ottobre 2026"])
        XCTAssertEqual(months[0].count, "4 sessioni")

        let november = months[0].weeks
        XCTAssertEqual(november.map(\.label), ["16 – 22 novembre", "9 – 15 novembre", "26 ott – 1 nov"])
        XCTAssertEqual(november.map(\.count), ["1 sessione", "2 sessioni", "1 sessione"])
        // Giorno con due sessioni: in ordine di inizio.
        let thursday = november[1].days[0]
        XCTAssertEqual(thursday.weekday, "GIO")
        XCTAssertEqual(thursday.number, "12")
        XCTAssertEqual(thursday.items.map(\.id), [3, 1])

        // La settimana a cavallo compare anche in ottobre, con le sole sessioni di ottobre.
        XCTAssertEqual(months[1].weeks.map(\.label), ["26 ott – 1 nov"])
        XCTAssertEqual(months[1].weeks[0].days.flatMap(\.items).map(\.id), [5])

        XCTAssertEqual(SessionHistory.months(items, year: 2025, calendar: calendar).map(\.title), ["Dicembre 2025"])
    }
}

final class SessionDetailTextTests: XCTestCase {
    func testTexts() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 11
        parts.day = 19
        parts.hour = 18
        parts.minute = 4
        let start = calendar.date(from: parts)!
        let end = start.addingTimeInterval(59 * 60)
        XCTAssertEqual(SessionDetailText.when(start: start, end: end, calendar: calendar),
                       "Giovedì 19 novembre, dalle 18:04 alle 19:03")
        XCTAssertEqual(SessionDetailText.approaches([]), "Avvicinamento —")
        XCTAssertEqual(SessionDetailText.reserve(.one), "riserva 1")
        XCTAssertEqual(SessionDetailText.reserve(.fourOrMore), "riserva 4+")
        XCTAssertNil(SessionDetailText.reserve(nil))
    }
}
