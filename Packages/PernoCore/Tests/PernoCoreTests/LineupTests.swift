import XCTest
@testable import PernoCore

final class LineupTests: XCTestCase {
    func testSections() {
        let lineup = Lineup(order: [0, 1, 4, 2, 3], position: 1, postponed: [4])
        XCTAssertEqual(lineup.done, [0])
        XCTAssertEqual(lineup.current, 1)
        XCTAssertEqual(lineup.upcoming, [2, 3])
        XCTAssertEqual(lineup.postponed, [4])
        XCTAssertEqual(lineup.tail, [2, 3, 4])

        let finished = Lineup(order: [0, 1], position: 2, postponed: [])
        XCTAssertEqual(finished.done, [0, 1])
        XCTAssertNil(finished.current)
        XCTAssertEqual(finished.upcoming, [])
    }

    func testMovesAndBringForward() {
        let lineup = Lineup(order: [0, 1, 2, 3, 4], position: 0, postponed: [4])
        XCTAssertEqual(lineup.movingUpcoming(from: [2], to: 0), [3, 1, 2, 4])
        XCTAssertEqual(lineup.bringingForward(4), [4, 1, 2, 3])
    }

    func testMachineReorderAndPostpone() throws {
        let t0 = Date(timeIntervalSince1970: 0)
        let exercises = (0..<4).map {
            PlannedExercise(name: "E\($0)", sets: [PlannedSet(kind: .work, weight: 10, reps: 10)])
        }
        var session = SessionMachine(exercises: exercises, warmUp: false, at: t0)
        try session.postponeCurrent()
        XCTAssertEqual(session.order, [1, 2, 3, 0])
        let lineup = Lineup(order: session.order, position: session.position, postponed: [0])
        try session.reorderUpcoming(lineup.bringingForward(0))
        XCTAssertEqual(session.order, [1, 0, 2, 3])
        XCTAssertThrowsError(try session.reorderUpcoming([0, 2]))
        XCTAssertThrowsError(try session.reorderUpcoming([1, 2, 3]))
    }

    func testTexts() {
        XCTAssertEqual(LineupText.progress(done: 1, total: 3), "1 di 3")
        XCTAssertEqual(LineupText.sets(3), "3 set")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(LineupText.postponed(at: Date(timeIntervalSince1970: 18 * 3600 + 5 * 60), calendar: calendar),
                       "Macchinario occupato alle 18:05")
        XCTAssertEqual(LineupText.postponed(at: nil), "Macchinario occupato")
        XCTAssertEqual(LineupText.subtitle(routine: "Upper body"), "Upper body, oggi. La scheda non cambia")
    }
}
