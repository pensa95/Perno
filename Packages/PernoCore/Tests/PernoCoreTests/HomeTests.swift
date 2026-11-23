import XCTest
@testable import PernoCore

final class HomeTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }()

    /// Novembre 2026: il 23 è lunedì, il 26 giovedì.
    private func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    func testWeekStartAndLetters() {
        XCTAssertEqual(WeekCalendar.weekStart(of: date(26, 20), calendar: calendar), date(23, 0))
        XCTAssertEqual(WeekCalendar.weekStart(of: date(29, 23), calendar: calendar), date(23, 0))
        XCTAssertEqual(Weekday.all.map(WeekCalendar.letter), ["L", "M", "M", "G", "V", "S", "D"])
        XCTAssertEqual(WeekCalendar.shortName("Upper body"), "Upper")
        XCTAssertEqual(WeekCalendar.shortName(""), "Libera")
    }

    /// La settimana della tavola A: lunedì fatto, martedì saltato, giovedì oggi da fare, sabato in programma.
    func testCalendarMatchesBoard() {
        let plan = [1: "upper", 2: "gambe", 4: "upper", 6: "gambe"]
        let names = ["upper": "Upper body", "gambe": "Gambe"]
        let sessions = [FinishedSession(start: date(23, 18), routine: Optional("upper"), name: "Upper body")]
        let days = WeekCalendar.days(today: date(26, 9), plan: plan, names: names,
                                     sessions: sessions, calendar: calendar)
        XCTAssertEqual(days.map(\.status), [.done, .skipped, .rest, .planned, .rest, .planned, .rest])
        XCTAssertEqual(days.map(\.label), ["Upper", "Gambe", "", "Upper", "", "Gambe", ""])
        XCTAssertEqual(days.map(\.isToday), [false, false, false, true, false, false, false])

        // Oggi fatto; una sessione libera in un giorno di riposo conta come fatta.
        let more = sessions + [
            FinishedSession(start: date(26, 19), routine: Optional("upper"), name: "Upper body"),
            FinishedSession(start: date(25, 8), routine: nil, name: ""),
        ]
        let after = WeekCalendar.days(today: date(26, 21), plan: plan, names: names,
                                      sessions: more, calendar: calendar)
        XCTAssertEqual(after.map(\.status), [.done, .skipped, .done, .done, .rest, .planned, .rest])
        XCTAssertEqual(after[2].label, "Libera")
    }

    func testSessionAfterMidnightCountsForItsStartDay() {
        // Iniziata martedì alle 23:30 e finita mercoledì: conta per martedì.
        let sessions = [FinishedSession(start: date(24, 23).addingTimeInterval(1800), routine: Optional("g"), name: "Gambe")]
        let days = WeekCalendar.days(today: date(26), plan: [2: "g", 3: "g"], names: ["g": "Gambe"],
                                     sessions: sessions, calendar: calendar)
        XCTAssertEqual(days[1].status, .done)
        XCTAssertEqual(days[2].status, .skipped)
    }

    func testProposal() {
        let plan = [1: "a", 4: "b"]
        XCTAssertEqual(TodayPlan.proposal(weekday: 4, plan: plan, planIsSet: true, routines: ["a", "b"], lastDone: [:]), "b")
        XCTAssertNil(TodayPlan.proposal(weekday: 3, plan: plan, planIsSet: true, routines: ["a", "b"], lastDone: [:]))

        // Senza piano: la meno recente, prima quelle mai fatte.
        let last = ["a": date(20), "b": date(22)]
        XCTAssertEqual(TodayPlan.proposal(weekday: 3, plan: [:], planIsSet: false, routines: ["a", "b"], lastDone: last), "a")
        XCTAssertEqual(TodayPlan.proposal(weekday: 3, plan: [:], planIsSet: false, routines: ["a", "b", "c"], lastDone: last), "c")
        XCTAssertNil(TodayPlan.proposal(weekday: 3, plan: [:], planIsSet: false, routines: [String](), lastDone: [:]))
    }

    func testNextWorkout() {
        let plan = [1: "a", 4: "b", 6: "a"]
        XCTAssertEqual(TodayPlan.next(after: 4, plan: plan)?.weekday, 6)
        XCTAssertEqual(TodayPlan.next(after: 6, plan: plan)?.weekday, 1)
        XCTAssertEqual(TodayPlan.next(after: 1, plan: [1: "a"])?.weekday, 1)
        XCTAssertNil(TodayPlan.next(after: 1, plan: [Int: String]()))
    }

    func testTexts() {
        XCTAssertEqual(HomeText.exercises(["Chest press", "Lat machine", "Shoulder press", "Pulley basso", "Croci ai cavi"], minutes: 55),
                       "Chest press, Lat machine, Shoulder press e altri 2, circa 55 minuti")
        XCTAssertEqual(HomeText.exercises(["A", "B", "C", "D"], minutes: 40), "A, B, C e un altro, circa 40 minuti")
        XCTAssertEqual(HomeText.exercises(["A", "B"], minutes: 20), "A e B, circa 20 minuti")
        XCTAssertEqual(HomeText.exercises([], minutes: 5), "Nessun esercizio")
        XCTAssertEqual(HomeText.duration(3520), "58:40")
        XCTAssertEqual(HomeText.duration(3920), "1:05:20")
        XCTAssertEqual(HomeText.volume(6240.4), "6.240")
        XCTAssertEqual(HomeText.volume(1_234_567), "1.234.567")
        XCTAssertEqual(HomeText.volume(950), "950")
        XCTAssertEqual(HomeText.liftedKilograms([(.approach, 30, 10), (.work, 60, 10), (.work, 62.5, 8)]), 1100)
    }
}
