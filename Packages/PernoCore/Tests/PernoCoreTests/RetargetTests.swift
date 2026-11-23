import XCTest
@testable import PernoCore

final class RetargetTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 20_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    /// Prima volta: obiettivi a 0, due avvicinamenti e tre set.
    private func firstTime() -> SessionMachine {
        SessionMachine(exercises: [
            PlannedExercise(name: "Chest press", sets: [
                PlannedSet(kind: .approach, weight: 0, reps: 10),
                PlannedSet(kind: .approach, weight: 0, reps: 6),
                PlannedSet(kind: .work, weight: 0, reps: 8),
                PlannedSet(kind: .work, weight: 0, reps: 8),
                PlannedSet(kind: .work, weight: 0, reps: 8),
            ]),
        ], warmUp: false, at: t0)
    }

    func testFirstWorkSetRetargetsFollowingSetsAndApproaches() throws {
        var session = firstTime()
        let changed = try session.retargetSet(exercise: 0, set: 2, weight: 60, reps: 10, kind: .work, step: 2.5)
        XCTAssertEqual(changed, [0, 1, 2, 3, 4])
        XCTAssertEqual(session.exercises[0].sets.map(\.weight), [30, 45, 60, 60, 60])
        XCTAssertEqual(session.exercises[0].sets[2].reps, 10)
        XCTAssertEqual(session.exercises[0].sets[3].reps, 8)
        XCTAssertEqual(session.currentSet?.weight, 30)

        try session.start(at: at(10))
        try session.countdownFinished(at: at(13))
        try session.setDone(at: at(40))
        XCTAssertEqual(session.completedSets.last?.weight, 30)
    }

    func testManualApproachIsKeptAndDoneSetsAreRefused() throws {
        var session = firstTime()
        try session.retargetSet(exercise: 0, set: 0, weight: 20, reps: 10, kind: .approach, step: 2.5)
        let changed = try session.retargetSet(exercise: 0, set: 2, weight: 60, reps: 8, kind: .work, step: 2.5)
        XCTAssertEqual(changed, [1, 2, 3, 4])
        XCTAssertEqual(session.exercises[0].sets.map(\.weight), [20, 45, 60, 60, 60])

        try session.start(at: at(10))
        try session.countdownFinished(at: at(13))
        try session.setDone(at: at(40))
        XCTAssertThrowsError(try session.retargetSet(exercise: 0, set: 0, weight: 25, reps: 10,
                                                     kind: .approach, step: 2.5))
        XCTAssertTrue(session.isDone(exercise: 0, set: 0))
        XCTAssertFalse(session.isDone(exercise: 0, set: 1))
    }

    func testLaterWorkSetOnlyChangesTheOnesAfter() throws {
        var session = firstTime()
        let changed = try session.retargetSet(exercise: 0, set: 3, weight: 55, reps: 8, kind: .work, step: 2.5)
        XCTAssertEqual(changed, [3, 4])
        XCTAssertEqual(session.exercises[0].sets.map(\.weight), [0, 0, 0, 55, 55])
    }
}

final class TargetSubtitleTests: XCTestCase {
    func testTargetSubtitle() {
        XCTAssertEqual(SetCorrection.targetSubtitle(exercise: "Chest press"), "Chest press, obiettivo")
    }
}
