import XCTest
@testable import PernoCore

final class SetCorrectionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 9_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// Prima volta: obiettivi a 0, un avvicinamento e tre set.
    private func firstTime() throws -> SessionMachine {
        var session = SessionMachine(exercises: [
            PlannedExercise(name: "Chest press", sets: [
                PlannedSet(kind: .approach, weight: 0, reps: 8),
                PlannedSet(kind: .work, weight: 0, reps: 8),
                PlannedSet(kind: .work, weight: 0, reps: 8),
                PlannedSet(kind: .work, weight: 0, reps: 8),
            ]),
        ], warmUp: false, at: t0)
        for start in [10.0, 100.0] {
            try session.start(at: at(start))
            try session.countdownFinished(at: at(start + 3))
            try session.setDone(at: at(start + 30))
        }
        return session
    }

    func testCorrectingAWorkSetRetargetsTheNextOnes() throws {
        var session = try firstTime()
        let changed = try session.correctSet(exercise: 0, set: 1, weight: 62.5, reps: 9, kind: .work)
        XCTAssertEqual(changed, [2, 3])
        XCTAssertEqual(session.completedSets[1].weight, 62.5)
        XCTAssertEqual(session.completedSets[1].reps, 9)
        XCTAssertEqual(session.exercises[0].sets[2].weight, 62.5)
        XCTAssertEqual(session.currentSet?.weight, 62.5)
        XCTAssertEqual(session.exercises[0].sets[0].weight, 0)     // l'avvicinamento fatto non cambia

        try session.start(at: at(200))
        try session.countdownFinished(at: at(203))
        try session.setDone(at: at(230))
        XCTAssertEqual(session.completedSets.last?.weight, 62.5)
    }

    func testCorrectingAnApproachDoesNotRetarget() throws {
        var session = try firstTime()
        let changed = try session.correctSet(exercise: 0, set: 0, weight: 30, reps: 8, kind: .approach)
        XCTAssertEqual(changed, [])
        XCTAssertEqual(session.completedSets[0].weight, 30)
    }

    func testCorrectingWithSameWeightOrUnknownSet() throws {
        var session = try firstTime()
        XCTAssertEqual(try session.correctSet(exercise: 0, set: 1, weight: 0, reps: 7, kind: .failure), [])
        XCTAssertEqual(session.completedSets[1].kind, .failure)
        XCTAssertThrowsError(try session.correctSet(exercise: 0, set: 3, weight: 50, reps: 8, kind: .work))
    }

    func testRemoveSet() throws {
        var session = try firstTime()
        try session.removeSet(exercise: 0, set: 0)
        XCTAssertEqual(session.completedSets.map(\.setIndex), [1])
        XCTAssertThrowsError(try session.removeSet(exercise: 0, set: 0))
    }

    func testHelpers() {
        XCTAssertEqual(SetCorrection.stepWeight(60, by: 2.5), 62.5)
        XCTAssertEqual(SetCorrection.stepWeight(1, by: -2.5), 0)
        XCTAssertEqual(SetCorrection.parseWeight("62,5"), 62.5)
        XCTAssertEqual(SetCorrection.parseWeight(" 70.25 "), 70.25)
        XCTAssertEqual(SetCorrection.parseWeight("900"), 500)
        XCTAssertNil(SetCorrection.parseWeight("abc"))
        XCTAssertEqual(SetCorrection.parseReps("12"), 12)
        XCTAssertEqual(SetCorrection.parseReps("0"), 1)
        XCTAssertNil(SetCorrection.parseReps("1,5"))
        XCTAssertEqual(SetCorrection.details(kind: .work, reserve: .one), "Set normale, ne avevi ancora 1")
        XCTAssertEqual(SetCorrection.details(kind: .failure, reserve: nil), "Set a cedimento")
        XCTAssertEqual(SetCorrection.subtitle(exercise: "Chest press", duration: 31), "Chest press, fatto in 0:31")
    }
}
