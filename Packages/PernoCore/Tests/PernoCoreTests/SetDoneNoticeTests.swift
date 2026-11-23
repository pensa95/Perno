import XCTest
@testable import PernoCore

final class SetDoneNoticeTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 5_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func machine() -> SessionMachine {
        SessionMachine(exercises: [
            PlannedExercise(name: "A", sets: [PlannedSet(kind: .work, weight: 60, reps: 10),
                                              PlannedSet(kind: .work, weight: 60, reps: 10)]),
            PlannedExercise(name: "B", sets: [PlannedSet(kind: .work, weight: 40, reps: 12)]),
        ], warmUp: false, at: t0)
    }

    private func doSet(_ session: inout SessionMachine, from start: TimeInterval) throws {
        try session.start(at: at(start))
        try session.countdownFinished(at: at(start + 3))
        try session.setDone(at: at(start + 33))
    }

    func testCorrectRepsOfLastSet() throws {
        var session = machine()
        XCTAssertThrowsError(try session.correctLastSet(reps: 9))
        try doSet(&session, from: 10)
        try session.correctLastSet(reps: 9)
        XCTAssertEqual(session.completedSets.last?.reps, 9)
        try session.correctLastSet(reps: 0)
        XCTAssertEqual(session.completedSets.last?.reps, 1)
    }

    func testUndoDuringRestGoesBackToSetInProgress() throws {
        var session = machine()
        try doSet(&session, from: 10)
        XCTAssertEqual(session.phase, .rest(since: at(43)))
        try session.undoLastSet()
        XCTAssertEqual(session.phase, .inSet(since: at(13)))
        XCTAssertEqual(session.setIndex, 0)
        XCTAssertTrue(session.completedSets.isEmpty)
        XCTAssertEqual(session.pauses.count, 1)          // il cambio iniziale resta
    }

    func testUndoDuringChangeoverAndAtTheEnd() throws {
        var session = machine()
        try doSet(&session, from: 10)
        try doSet(&session, from: 100)
        XCTAssertEqual(session.currentExerciseIndex, 1)
        try session.undoLastSet()
        XCTAssertEqual(session.currentExerciseIndex, 0)
        XCTAssertEqual(session.setIndex, 1)
        XCTAssertEqual(session.phase, .inSet(since: at(103)))

        try session.setDone(at: at(140))
        try doSet(&session, from: 200)
        XCTAssertEqual(session.phase, .finished)
        try session.undoLastSet()
        XCTAssertEqual(session.currentExerciseIndex, 1)
        XCTAssertEqual(session.phase, .inSet(since: at(203)))
    }

    func testUndoIsRefusedOnceRestarted() throws {
        var session = machine()
        XCTAssertThrowsError(try session.undoLastSet())   // nessun set fatto
        try doSet(&session, from: 10)
        try session.start(at: at(100))
        XCTAssertThrowsError(try session.undoLastSet())   // durante il 3-2-1
    }
}
