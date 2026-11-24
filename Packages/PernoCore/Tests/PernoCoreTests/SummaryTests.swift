import XCTest
@testable import PernoCore

final class SummaryTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 80_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func plan() -> [PlannedExercise] {
        [
            PlannedExercise(name: "A", sets: [PlannedSet(kind: .work, weight: 60, reps: 10),
                                              PlannedSet(kind: .work, weight: 60, reps: 10)]),
            PlannedExercise(name: "B", sets: [PlannedSet(kind: .work, weight: 40, reps: 12),
                                              PlannedSet(kind: .work, weight: 40, reps: 12)]),
            PlannedExercise(name: "C", sets: [PlannedSet(kind: .work, weight: 20, reps: 12)]),
        ]
    }

    private func doSet(_ session: inout SessionMachine, at seconds: TimeInterval) throws {
        try session.start(at: at(seconds))
        try session.countdownFinished(at: at(seconds + 3))
        try session.setDone(at: at(seconds + 30))
    }

    // MARK: Testi e numeri

    func testRecord() {
        typealias Lift = SessionSummary.Lift
        let record = SessionSummary.record(exercise: "Lat machine",
                                           today: [Lift(weight: 50, reps: 12), Lift(weight: 55, reps: 10)],
                                           previous: [Lift(weight: 50, reps: 12), Lift(weight: 52.5, reps: 10)])
        XCTAssertEqual(record?.lift, Lift(weight: 55, reps: 10))
        XCTAssertEqual(record?.title, "Record su Lat machine")
        XCTAssertEqual(record?.detail, "55 × 10, massimale stimato 73 kg")

        XCTAssertNil(SessionSummary.record(exercise: "X", today: [Lift(weight: 60, reps: 10)], previous: []))
        XCTAssertNil(SessionSummary.record(exercise: "X", today: [Lift(weight: 60, reps: 10)],
                                           previous: [Lift(weight: 60, reps: 10)]))
        XCTAssertNil(SessionSummary.record(exercise: "X", today: [Lift(weight: 0, reps: 20)],
                                           previous: [Lift(weight: 0, reps: 10)]))
        XCTAssertEqual(Lift(weight: 100, reps: 1).estimatedMax, 100)
    }

    func testVolumeChangeAndUndoneTexts() {
        XCTAssertEqual(SessionSummary.volumeChange(today: 6_240, previous: 6_120), "+2%")
        XCTAssertEqual(SessionSummary.volumeChange(today: 5_000, previous: 6_000), "−17%")
        XCTAssertEqual(SessionSummary.volumeChange(today: 6_000, previous: 6_010), "0%")
        XCTAssertNil(SessionSummary.volumeChange(today: 6_000, previous: nil))
        XCTAssertNil(SessionSummary.volumeChange(today: 6_000, previous: 0))

        XCTAssertEqual(SessionSummary.undoneTitle(exercise: "Croci ai cavi", count: 1), "Croci ai cavi, 1 set non fatto")
        XCTAssertEqual(SessionSummary.undoneTitle(exercise: "Croci ai cavi", count: 2), "Croci ai cavi, 2 set non fatti")
        XCTAssertEqual(SessionSummary.undoneSubtitle(count: 1), "Puoi farlo adesso o lasciarlo")
        XCTAssertEqual(SessionSummary.undoneSubtitle(count: 3), "Puoi farli adesso o lasciarli")
    }

    func testTimeBar() {
        let breakdown = TimeBreakdown(warmUp: 7 * 60, work: 12 * 60, rest: 29 * 60, changeover: 10 * 60)
        let fractions = SessionSummary.fractions(breakdown)
        XCTAssertEqual(fractions[.rest] ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(fractions.values.reduce(0, +), 1, accuracy: 0.001)
        XCTAssertEqual(SessionSummary.minutes(7 * 60 + 20), "7 min")
        XCTAssertEqual(SessionSummary.accessibilityLabel(breakdown),
                       "Riscaldamento 7, lavoro 12, recupero 29, cambi 10 minuti")
        XCTAssertTrue(SessionSummary.fractions(TimeBreakdown(warmUp: 0, work: 0, rest: 0, changeover: 0)).isEmpty)
    }

    // MARK: «Completa»

    func testCompleteAfterConcludingMidSession() throws {
        var session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        try doSet(&session, at: 10)          // A set 1
        try doSet(&session, at: 100)         // A set 2 → cambio su B
        try doSet(&session, at: 200)         // B set 1 → recupero
        XCTAssertEqual(session.currentExerciseIndex, 1)

        // «Concludi», poi «Completa» su C: C adesso, B subito dopo.
        try session.complete(exercise: 2, at: at(300))
        XCTAssertEqual(session.phase, .changeover(since: at(300)))
        XCTAssertEqual(session.currentExerciseIndex, 2)
        XCTAssertEqual(session.setIndex, 0)
        XCTAssertEqual(session.order, [0, 2, 1])

        try doSet(&session, at: 310)
        XCTAssertEqual(session.currentExerciseIndex, 1)
        XCTAssertEqual(session.setIndex, 1)
        try doSet(&session, at: 400)
        XCTAssertEqual(session.phase, .finished)
        XCTAssertEqual(session.completedSets.count, 5)
    }

    func testCompleteTheCurrentExerciseKeepsThePhase() throws {
        var session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        try doSet(&session, at: 10)
        let phase = session.phase
        try session.complete(exercise: 0, at: at(500))
        XCTAssertEqual(session.phase, phase)
        XCTAssertThrowsError(try session.complete(exercise: 5, at: at(500)))
    }

    func testCompleteAfterTheEndReopensTheSession() throws {
        var session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        try doSet(&session, at: 10)
        try doSet(&session, at: 100)
        try doSet(&session, at: 200)
        try doSet(&session, at: 300)
        try doSet(&session, at: 400)
        XCTAssertEqual(session.phase, .finished)
        try session.removeSet(exercise: 1, set: 0)

        try session.complete(exercise: 1, at: at(600))
        XCTAssertEqual(session.currentExerciseIndex, 1)
        XCTAssertEqual(session.setIndex, 0)
        try doSet(&session, at: 610)
        XCTAssertEqual(session.phase, .finished)
        XCTAssertThrowsError(try session.complete(exercise: 1, at: at(700)))
    }

    func testSetDoneSkipsSetsAlreadyDone() throws {
        var session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        try doSet(&session, at: 10)
        try doSet(&session, at: 100)
        try doSet(&session, at: 200)         // B set 1
        try session.complete(exercise: 2, at: at(250))
        try doSet(&session, at: 260)         // C → poi B dal set 2
        try session.removeSet(exercise: 0, set: 0)
        try session.complete(exercise: 0, at: at(300))
        try doSet(&session, at: 310)         // A set 1 rifatto: A è finito, si torna a B
        XCTAssertEqual(session.currentExerciseIndex, 1)
        XCTAssertEqual(session.setIndex, 1)
        XCTAssertEqual(session.phase, .changeover(since: at(340)))
    }

    func testUndoAfterSkippingFinishedExercises() throws {
        var session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        try doSet(&session, at: 10)
        try doSet(&session, at: 100)
        try doSet(&session, at: 200)
        try session.complete(exercise: 2, at: at(250))
        try doSet(&session, at: 260)
        try session.undoLastSet()
        XCTAssertEqual(session.currentExerciseIndex, 2)
        XCTAssertEqual(session.phase, .inSet(since: at(263)))
    }
}
