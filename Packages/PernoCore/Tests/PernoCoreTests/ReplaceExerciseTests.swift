import XCTest
@testable import PernoCore

final class ReplaceExerciseTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let set = PlannedSet(kind: .work, weight: 60, reps: 10)

    private func macchina() -> SessionMachine {
        SessionMachine(exercises: [
            PlannedExercise(name: "Chest press", sets: [PlannedSet(kind: .approach, weight: 30, reps: 10), set, set, set]),
            PlannedExercise(name: "Lat machine", sets: [set, set]),
        ], warmUp: false, at: t0)
    }

    private func fai(_ m: inout SessionMachine, alle secondi: TimeInterval) throws {
        try m.start(at: t0.addingTimeInterval(secondi))
        try m.countdownFinished(at: t0.addingTimeInterval(secondi + 3))
        try m.setDone(at: t0.addingTimeInterval(secondi + 40))
    }

    private let nuovo = PlannedExercise(name: "Panca piana", sets: [PlannedSet(kind: .work, weight: 50, reps: 10),
                                                                   PlannedSet(kind: .work, weight: 50, reps: 10)])

    func testDoneSetsStayUndoneMoveToNewExercise() throws {
        var m = macchina()
        try fai(&m, alle: 0)     // Avv. 1
        try fai(&m, alle: 100)   // Set 1
        XCTAssertEqual(m.phase, .rest(since: t0.addingTimeInterval(140)))
        let indice = try m.replaceExercise(0, with: nuovo, at: t0.addingTimeInterval(160))
        XCTAssertEqual(indice, 2)
        // Sul vecchio restano solo i set fatti, con gli indici rinumerati.
        XCTAssertEqual(m.exercises[0].sets.count, 2)
        XCTAssertEqual(m.completedSets.filter { $0.exerciseIndex == 0 }.map(\.setIndex), [0, 1])
        XCTAssertNil(m.firstUndoneSet(of: 0))
        // Il nuovo entra subito dopo e diventa quello di adesso, nel cambio dall'ultimo «Set fatto».
        XCTAssertEqual(m.order, [0, 2, 1])
        XCTAssertEqual(m.currentExerciseIndex, 2)
        XCTAssertEqual(m.setIndex, 0)
        XCTAssertEqual(m.phase, .changeover(since: t0.addingTimeInterval(140)))
        // Finito il nuovo si passa al successivo dell'ordine di oggi.
        try fai(&m, alle: 200)
        try fai(&m, alle: 300)
        XCTAssertEqual(m.currentExerciseIndex, 1)
    }

    func testReplaceBeforeStartingKeepsChangeover() throws {
        var m = macchina()
        try m.replaceExercise(0, with: nuovo, at: t0.addingTimeInterval(5))
        XCTAssertEqual(m.exercises[0].sets.count, 0)
        XCTAssertEqual(m.order, [2, 1])
        XCTAssertEqual(m.currentExerciseIndex, 2)
        XCTAssertEqual(m.phase, .changeover(since: t0))
    }

    func testReplaceUpcomingExerciseKeepsCurrent() throws {
        var m = macchina()
        try fai(&m, alle: 0)
        try m.replaceExercise(1, with: nuovo, at: t0.addingTimeInterval(60))
        XCTAssertEqual(m.order, [0, 2])
        XCTAssertEqual(m.currentExerciseIndex, 0)
        XCTAssertEqual(m.setIndex, 1)
        XCTAssertEqual(m.exercises[1].sets.count, 0)
    }

    func testCannotReplaceDuringSetOrWhenAllDone() throws {
        var m = macchina()
        try m.start(at: t0)
        XCTAssertFalse(m.canReplace(exercise: 0))
        XCTAssertTrue(m.canReplace(exercise: 1))
        try m.countdownFinished(at: t0.addingTimeInterval(3))
        XCTAssertThrowsError(try m.replaceExercise(0, with: nuovo, at: t0.addingTimeInterval(10)))
        XCTAssertThrowsError(try m.replaceExercise(1, with: PlannedExercise(name: "Vuoto", sets: []),
                                                   at: t0.addingTimeInterval(10)))
    }
}
