import XCTest
@testable import PernoCore

final class SessionTextTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(SessionText.clock(24.9), "0:24")
        XCTAssertEqual(SessionText.clock(662), "11:02")
        XCTAssertEqual(SessionText.clock(3920), "1:05:20")
        XCTAssertEqual(SessionText.clock(-5), "0:00")
    }

    func testNumbersPerKind() {
        XCTAssertEqual(SessionText.numbers([.approach, .approach, .work, .work, .work]), [1, 2, 1, 2, 3])
        XCTAssertEqual(SessionText.numbers([]), [])
    }

    func testTitles() {
        XCTAssertEqual(SessionText.shortName(.approach, 1), "Avv. 1")
        XCTAssertEqual(SessionText.shortName(.work, 2), "Set 2")
        XCTAssertEqual(SessionText.startTitle(.approach, 1), "Inizia avvicinamento 1")
        XCTAssertEqual(SessionText.startTitle(.work, 2), "Inizia set 2")
        XCTAssertEqual(SessionText.doneTitle(.work, 1), "Set 1 fatto")
        XCTAssertEqual(SessionText.inProgress(.work, 1), "Set 1 in corso")
        XCTAssertEqual(SessionText.countdownTitle(.work, 1), "Set 1 tra")
        XCTAssertEqual(SessionText.countdownTitle(.approach, 2), "Avvicinamento 2 tra")
    }

    func testWeightsAndDelta() {
        XCTAssertEqual(SessionText.weightReps(62.5, 10), "62,5 × 10")
        XCTAssertEqual(SessionText.delta(today: 62.5, before: 60), "+2,5 kg")
        XCTAssertEqual(SessionText.delta(today: 57.5, before: 60), "−2,5 kg")
        XCTAssertNil(SessionText.delta(today: 60, before: 60))
    }

    func testHeaderAndRest() {
        XCTAssertEqual(SessionText.exerciseHeader(position: 1, count: 5, repsMin: 8, repsMax: 12),
                       "Esercizio 1 di 5, da 8 a 12 ripetizioni")
        XCTAssertEqual(SessionText.exerciseHeader(position: 2, count: 2, repsMin: 10, repsMax: 10),
                       "Esercizio 2 di 2, 10 ripetizioni")
        XCTAssertEqual(SessionText.restLabel(usual: 130), "Recupero, di solito 2:10")
        XCTAssertEqual(SessionText.restLabel(usual: nil), "Recupero")
    }

    func testApproachPercentAndCountdown() {
        XCTAssertEqual(SessionText.approachPercent(number: 1, count: 2), "50%")
        XCTAssertEqual(SessionText.approachPercent(number: 2, count: 2), "75%")
        XCTAssertNil(SessionText.approachPercent(number: 3, count: 2))
        XCTAssertEqual(SessionText.countdownValue(elapsed: 0, total: 3), 3)
        XCTAssertEqual(SessionText.countdownValue(elapsed: 1.2, total: 3), 2)
        XCTAssertEqual(SessionText.countdownValue(elapsed: 2.9, total: 3), 1)
        XCTAssertEqual(SessionText.countdownValue(elapsed: 5, total: 3), 1)
    }

    func testCancelCountdownReturnsToPause() throws {
        let t0 = Date(timeIntervalSince1970: 1_000)
        var session = SessionMachine(exercises: [
            PlannedExercise(name: "A", sets: [PlannedSet(kind: .work, weight: 50, reps: 10),
                                              PlannedSet(kind: .work, weight: 50, reps: 10)]),
        ], warmUp: false, at: t0)
        try session.start(at: t0.addingTimeInterval(20))
        try session.cancelCountdown()
        XCTAssertEqual(session.phase, .changeover(since: t0))
        XCTAssertTrue(session.pauses.isEmpty)

        try session.start(at: t0.addingTimeInterval(30))
        try session.countdownFinished(at: t0.addingTimeInterval(33))
        try session.setDone(at: t0.addingTimeInterval(60))
        try session.start(at: t0.addingTimeInterval(150))
        try session.cancelCountdown()
        XCTAssertEqual(session.phase, .rest(since: t0.addingTimeInterval(60)))
        XCTAssertThrowsError(try session.cancelCountdown())

        session.finish()
        XCTAssertEqual(session.phase, .finished)
    }
}

final class NoticeTitleTests: XCTestCase {
    func testNoticeTitle() {
        XCTAssertEqual(SessionText.noticeTitle(.work, 1, weight: 62.5), "Set 1, 62,5 ×")
        XCTAssertEqual(SessionText.noticeTitle(.approach, 2, weight: 45), "Avv. 2, 45 ×")
    }
}
