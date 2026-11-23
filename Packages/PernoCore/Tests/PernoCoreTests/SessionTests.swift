import XCTest
@testable import PernoCore

final class SessionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func plan() -> [PlannedExercise] {
        [
            PlannedExercise(name: "Chest press", sets: [
                PlannedSet(kind: .approach, weight: 30, reps: 10),
                PlannedSet(kind: .work, weight: 62.5, reps: 10),
                PlannedSet(kind: .work, weight: 62.5, reps: 10),
            ]),
            PlannedExercise(name: "Lat machine", sets: [
                PlannedSet(kind: .work, weight: 55, reps: 10),
            ]),
        ]
    }

    func testFullCycleRecordsMeasuredTimes() throws {
        var session = SessionMachine(exercises: plan(), warmUp: true, at: at(0))
        XCTAssertEqual(session.phase, .warmUp(since: at(0)))

        try session.endWarmUp(at: at(300))                 // riscaldamento 5:00
        try session.start(at: at(330))                     // cambio 0:30
        try session.countdownFinished(at: at(333))         // 3-2-1 escluso
        try session.setDone(at: at(363))                   // avvicinamento 0:30
        XCTAssertEqual(session.phase, .rest(since: at(363)))

        try session.start(at: at(423))                     // recupero dopo avvicinamento 1:00
        try session.countdownFinished(at: at(426))
        try session.setDone(at: at(466), reps: 9)          // set 1 corretto a 9
        try session.start(at: at(596))                     // recupero 2:10
        try session.countdownFinished(at: at(599))
        try session.setDone(at: at(639))                   // ultimo set dell'esercizio
        XCTAssertEqual(session.phase, .changeover(since: at(639)))
        XCTAssertEqual(session.currentExerciseIndex, 1)

        try session.start(at: at(729))                     // cambio 1:30
        try session.countdownFinished(at: at(732))
        try session.setDone(at: at(772))
        XCTAssertEqual(session.phase, .finished)

        XCTAssertEqual(session.completedSets.count, 4)
        XCTAssertEqual(session.completedSets[1].reps, 9)
        XCTAssertEqual(session.completedSets[1].weight, 62.5)
        XCTAssertEqual(session.completedSets.map(\.duration), [30, 40, 40, 40])

        let kinds = session.pauses.map(\.kind)
        XCTAssertEqual(kinds, [.warmUp, .changeover, .rest, .rest, .changeover])
        XCTAssertEqual(session.pauses.map(\.duration), [300, 30, 60, 130, 90])
        XCTAssertEqual(session.pauses.map(\.afterApproach), [false, false, true, false, false])

        let breakdown = SessionStats.breakdown(sets: session.completedSets, pauses: session.pauses)
        XCTAssertEqual(breakdown, TimeBreakdown(warmUp: 300, work: 150, rest: 190, changeover: 120))

        // Il recupero dopo l'avvicinamento non entra nella media.
        XCTAssertEqual(SessionStats.usualRest(session.pauses), 130)
    }

    func testWithoutWarmUpStartsInChangeover() {
        let session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        XCTAssertEqual(session.phase, .changeover(since: at(0)))
    }

    func testInvalidTransitionsThrow() throws {
        var session = SessionMachine(exercises: plan(), warmUp: true, at: at(0))
        XCTAssertThrowsError(try session.start(at: at(1)))
        XCTAssertThrowsError(try session.setDone(at: at(1)))
        try session.endWarmUp(at: at(10))
        XCTAssertThrowsError(try session.endWarmUp(at: at(11)))
        XCTAssertThrowsError(try session.countdownFinished(at: at(11)))
    }

    func testPostponeMovesExerciseToTheEnd() throws {
        var session = SessionMachine(exercises: plan(), warmUp: false, at: at(0))
        try session.postponeCurrent()
        XCTAssertEqual(session.order, [1, 0])
        XCTAssertEqual(session.currentExerciseIndex, 1)
        XCTAssertEqual(session.exercises.map(\.name), ["Chest press", "Lat machine"]) // la scheda non cambia

        // L'ultimo esercizio rimasto non si può rimandare.
        try session.start(at: at(10))
        try session.countdownFinished(at: at(13))
        try session.setDone(at: at(50))
        XCTAssertThrowsError(try session.postponeCurrent())
    }

    func testUsualRestWithoutDataIsNil() {
        XCTAssertNil(SessionStats.usualRest([]))
    }
}
