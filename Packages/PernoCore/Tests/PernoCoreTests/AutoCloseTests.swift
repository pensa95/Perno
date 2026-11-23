import XCTest
@testable import PernoCore

final class AutoCloseTests: XCTestCase {
    func testThresholdAndEnd() {
        let last = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(AutoClose.isDue(lastActivity: last, now: last.addingTimeInterval(3 * 3600 - 1)))
        XCTAssertTrue(AutoClose.isDue(lastActivity: last, now: last.addingTimeInterval(3 * 3600)))
        let set = Date(timeIntervalSince1970: 900)
        XCTAssertEqual(AutoClose.end(lastSetEnd: set, lastActivity: last), set)
        XCTAssertEqual(AutoClose.end(lastSetEnd: nil, lastActivity: last), last)
    }

    func testTexts() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        let end = Date(timeIntervalSince1970: 19 * 3600 + 42 * 60)
        XCTAssertEqual(AutoClose.message(end: end, hadSets: true, calendar: calendar),
                       "Nessuna attività per 3 ore. La durata finisce all'ultimo set, alle 19:42.")
        // 21 novembre 2026 è sabato.
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 11
        parts.day = 21
        parts.hour = 18
        let saturday = calendar.date(from: parts)!
        XCTAssertEqual(ItalianDate.long(saturday, calendar: calendar), "Sabato 21 novembre")
    }

    func testAddSet() throws {
        var session = SessionMachine(exercises: [
            PlannedExercise(name: "A", sets: [PlannedSet(kind: .approach, weight: 30, reps: 10),
                                              PlannedSet(kind: .work, weight: 60, reps: 9)]),
        ], warmUp: false, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(try session.addSet(toExercise: 0), 2)
        XCTAssertEqual(session.exercises[0].sets[2], PlannedSet(kind: .work, weight: 60, reps: 9))
        XCTAssertThrowsError(try session.addSet(toExercise: 3))
    }
}
