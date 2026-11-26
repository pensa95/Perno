import XCTest
@testable import PernoCore

final class DeleteSetTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func macchina() -> SessionMachine {
        let set = PlannedSet(kind: .work, weight: 60, reps: 10)
        return SessionMachine(exercises: [
            PlannedExercise(name: "A", sets: [set, set, set]),
            PlannedExercise(name: "B", sets: [set, set]),
        ], warmUp: false, at: t0)
    }

    /// Fa il set di adesso: Inizia → fine del 3-2-1 → Set fatto.
    private func fai(_ m: inout SessionMachine, alle secondi: TimeInterval) throws {
        try m.start(at: t0.addingTimeInterval(secondi))
        try m.countdownFinished(at: t0.addingTimeInterval(secondi + 3))
        try m.setDone(at: t0.addingTimeInterval(secondi + 40))
    }

    func testDeleteLaterSetDuringRest() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        XCTAssertEqual(m.phase, .rest(since: t0.addingTimeInterval(40)))
        try m.deleteUndoneSet(exercise: 0, set: 2, at: t0.addingTimeInterval(60))
        XCTAssertEqual(m.exercises[0].sets.count, 2)
        XCTAssertEqual(m.setIndex, 1)
        XCTAssertEqual(m.currentExerciseIndex, 0)
    }

    func testDeleteNextSetMovesToFollowingOne() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        try m.deleteUndoneSet(exercise: 0, set: 1, at: t0.addingTimeInterval(60))
        XCTAssertEqual(m.setIndex, 1)
        XCTAssertEqual(m.exercises[0].sets.count, 2)
        XCTAssertEqual(m.phase, .rest(since: t0.addingTimeInterval(40)))
    }

    func testDeleteLastRemainingSetGoesToChangeoverFromLastSetDone() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        try fai(&m, alle: 100)
        // Resta solo il set 3: toglierlo porta al cambio esercizio, con il tempo dall'ultimo «Set fatto».
        try m.deleteUndoneSet(exercise: 0, set: 2, at: t0.addingTimeInterval(200))
        XCTAssertEqual(m.currentExerciseIndex, 1)
        XCTAssertEqual(m.setIndex, 0)
        XCTAssertEqual(m.phase, .changeover(since: t0.addingTimeInterval(140)))
    }

    func testDeleteShiftsDoneSetIndexes() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        try fai(&m, alle: 100)
        // «Elimina set» sul set 1: torna da fare, il set 2 resta fatto; togliendo il set 1 il fatto scala.
        try m.removeSet(exercise: 0, set: 0)
        try m.deleteUndoneSet(exercise: 0, set: 0, at: t0.addingTimeInterval(200))
        XCTAssertEqual(m.completedSets.map(\.setIndex), [0])
        XCTAssertTrue(m.isDone(exercise: 0, set: 0))
        XCTAssertFalse(m.isDone(exercise: 0, set: 1))
    }

    func testCannotDeleteDoneCurrentOrLastSet() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        XCTAssertFalse(m.canDeleteUndoneSet(exercise: 0, set: 0))
        try m.start(at: t0.addingTimeInterval(100))
        // 3-2-1 e set in corso: il set di adesso non si toglie, gli altri sì.
        XCTAssertFalse(m.canDeleteUndoneSet(exercise: 0, set: 1))
        XCTAssertTrue(m.canDeleteUndoneSet(exercise: 0, set: 2))
        try m.countdownFinished(at: t0.addingTimeInterval(103))
        XCTAssertFalse(m.canDeleteUndoneSet(exercise: 0, set: 1))
        XCTAssertThrowsError(try m.deleteUndoneSet(exercise: 0, set: 1, at: t0.addingTimeInterval(110)))
        // Un esercizio tiene almeno un set.
        var solo = SessionMachine(exercises: [PlannedExercise(name: "C", sets: [PlannedSet(kind: .work, weight: 0, reps: 8)])],
                                  warmUp: false, at: t0)
        XCTAssertFalse(solo.canDeleteUndoneSet(exercise: 0, set: 0))
        XCTAssertThrowsError(try solo.deleteUndoneSet(exercise: 0, set: 0, at: t0))
    }

    func testDeleteInOtherExerciseKeepsCurrent() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        try m.deleteUndoneSet(exercise: 1, set: 1, at: t0.addingTimeInterval(60))
        XCTAssertEqual(m.exercises[1].sets.count, 1)
        XCTAssertEqual(m.currentExerciseIndex, 0)
        XCTAssertEqual(m.setIndex, 1)
    }
}
