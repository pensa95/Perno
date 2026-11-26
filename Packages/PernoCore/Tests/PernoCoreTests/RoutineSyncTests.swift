import XCTest
@testable import PernoCore

final class RoutineSyncTests: XCTestCase {
    private let a = UUID(), b = UUID(), c = UUID()
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func voce(_ id: UUID, sets: Int = 3, min: Int = 8, max: Int = 12, rest: Double? = nil,
                      setup: String = "", cues: String = "") -> RoutineSync.EntrySnapshot {
        RoutineSync.EntrySnapshot(id: id, setCount: sets, repsMin: min, repsMax: max, fixedRest: rest, setup: setup,
                                  cues: cues, restMode: "stopwatch", autoStartAfterRest: false)
    }

    func testNoChanges() {
        XCTAssertTrue(RoutineSync.changes(from: [voce(a), voce(b)], to: [voce(a), voce(b)]).isEmpty)
        // Spostare le voci nella scheda non cambia la sessione.
        XCTAssertTrue(RoutineSync.changes(from: [voce(a), voce(b)], to: [voce(b), voce(a)]).isEmpty)
    }

    func testAddedRemovedChanged() {
        let changes = RoutineSync.changes(from: [voce(a), voce(b)],
                                          to: [voce(c), voce(a, sets: 4, setup: "Sedile 4")])
        XCTAssertEqual(changes.added, [c])
        XCTAssertEqual(changes.removed, [b])
        XCTAssertEqual(changes.changed.count, 1)
        XCTAssertEqual(changes.changed.first?.workSetDelta, 1)
        XCTAssertEqual(changes.changed.first?.repsChanged, false)
        XCTAssertEqual(changes.changed.first?.after.setup, "Sedile 4")
    }

    func testRepsClamp() {
        XCTAssertEqual(RoutineSync.reps(12, min: 6, max: 10), 10)
        XCTAssertEqual(RoutineSync.reps(4, min: 6, max: 10), 6)
        XCTAssertEqual(RoutineSync.reps(8, min: 6, max: 10), 8)
        XCTAssertEqual(RoutineSync.changes(from: [voce(a)], to: [voce(a, min: 6, max: 10)]).changed.first?.repsChanged,
                       true)
    }

    private func macchina() -> SessionMachine {
        let set = PlannedSet(kind: .work, weight: 60, reps: 10)
        return SessionMachine(exercises: [PlannedExercise(name: "A", sets: [set, set]),
                                          PlannedExercise(name: "B", sets: [set]),
                                          PlannedExercise(name: "C", sets: [set])],
                              warmUp: false, at: t0)
    }

    func testDropUpcomingAndCurrentBeforeStart() throws {
        var m = macchina()
        try m.drop(exercise: 1, at: t0)
        XCTAssertEqual(m.order, [0, 2])
        XCTAssertEqual(m.currentExerciseIndex, 0)
        // Quello di adesso, prima del primo «Inizia»: tocca al successivo, nel cambio già in corso.
        try m.drop(exercise: 0, at: t0.addingTimeInterval(10))
        XCTAssertEqual(m.currentExerciseIndex, 2)
        XCTAssertEqual(m.phase, .changeover(since: t0))
        // L'ultimo rimasto: la sessione è finita.
        try m.drop(exercise: 2, at: t0.addingTimeInterval(20))
        XCTAssertEqual(m.phase, .finished)
    }

    func testCannotDropWithDoneSetsOrInProgress() throws {
        var m = macchina()
        try m.start(at: t0)
        XCTAssertFalse(m.canDrop(exercise: 0))
        try m.countdownFinished(at: t0.addingTimeInterval(3))
        try m.setDone(at: t0.addingTimeInterval(40))
        XCTAssertFalse(m.canDrop(exercise: 0))
        XCTAssertThrowsError(try m.drop(exercise: 0, at: t0.addingTimeInterval(50)))
        XCTAssertTrue(m.canDrop(exercise: 1))
    }
}
