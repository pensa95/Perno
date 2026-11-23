import XCTest
@testable import PernoCore

final class FreeSessionTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 70_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func exercise(_ name: String, sets: Int = 1) -> PlannedExercise {
        PlannedExercise(name: name, sets: Array(repeating: PlannedSet(kind: .work, weight: 50, reps: 10), count: sets))
    }

    func testFreeSessionGrowsAndNeverFinishesByItself() throws {
        var session = SessionMachine(openEndedAt: t0, warmUp: true)
        XCTAssertTrue(session.isOpenEnded)
        XCTAssertEqual(session.phase, .warmUp(since: t0))
        try session.endWarmUp(at: at(360))
        XCTAssertEqual(session.phase, .changeover(since: at(360)))
        XCTAssertNil(session.currentExerciseIndex)
        XCTAssertThrowsError(try session.start(at: at(370)))

        session.appendExercises([exercise("Leg press"), exercise("Leg curl")], at: at(380))
        XCTAssertEqual(session.currentExerciseIndex, 0)
        try session.start(at: at(400))
        try session.countdownFinished(at: at(403))
        try session.setDone(at: at(440))
        XCTAssertEqual(session.currentExerciseIndex, 1)
        try session.start(at: at(500))
        try session.countdownFinished(at: at(503))
        try session.setDone(at: at(540))
        XCTAssertEqual(session.phase, .changeover(since: at(540)))
        XCTAssertNil(session.currentExerciseIndex)

        session.appendExercises([exercise("Calf")], at: at(560))
        XCTAssertEqual(session.currentExerciseIndex, 2)
        XCTAssertEqual(session.order, [0, 1, 2])
    }

    func testRoutineSessionCanGrowAfterFinishing() throws {
        var session = SessionMachine(exercises: [exercise("A")], warmUp: false, at: t0)
        try session.start(at: at(10))
        try session.countdownFinished(at: at(13))
        try session.setDone(at: at(40))
        XCTAssertEqual(session.phase, .finished)
        session.appendExercises([exercise("B")], at: at(50))
        XCTAssertEqual(session.phase, .changeover(since: at(50)))
        XCTAssertEqual(session.currentExerciseIndex, 1)
    }

    func testResumeOpenEnded() {
        let empty = SessionMachine(resuming: [], completed: [], pauses: [], openEnded: true, at: at(100))
        XCTAssertEqual(empty.phase, .changeover(since: at(100)))
        let done = SessionMachine(resuming: [exercise("A")], completed: [
            CompletedSet(exerciseIndex: 0, setIndex: 0, kind: .work, weight: 50, reps: 10,
                         startedAt: at(10), endedAt: at(40)),
        ], pauses: [], openEnded: true, at: at(100))
        XCTAssertEqual(done.phase, .changeover(since: at(100)))
        XCTAssertNil(done.currentExerciseIndex)
    }

    func testTexts() {
        XCTAssertEqual(FreeSessionText.warmUpDone(372), "Riscaldamento fatto, 6 minuti")
        XCTAssertEqual(FreeSessionText.warmUpDone(50), "Riscaldamento fatto, 1 minuto")
        XCTAssertNil(FreeSessionText.warmUpDone(nil))
        XCTAssertEqual(FreeSessionText.title(exercisesSoFar: 0), "Primo esercizio")
        XCTAssertEqual(FreeSessionText.title(exercisesSoFar: 2), "Prossimo esercizio")
        XCTAssertEqual(FreeSessionText.lastTime((120, 10)), "Ultima volta 120 × 10")
        XCTAssertEqual(FreeSessionText.lastTime(nil), "Mai fatto")
        XCTAssertEqual(FreeSessionText.librarySubtitle(equipment: .machine, last: (62.5, 9)),
                       "Macchina, ultima volta 62,5 × 9")
        XCTAssertEqual(FreeSessionText.librarySubtitle(equipment: .machine, last: nil), "Macchina, mai fatto")
        XCTAssertEqual(FreeSessionText.addButton(0), "Aggiungi esercizi")
        XCTAssertEqual(FreeSessionText.addButton(1), "Aggiungi 1 esercizio")
        XCTAssertEqual(FreeSessionText.addButton(2), "Aggiungi 2 esercizi")
        XCTAssertEqual(FreeSessionText.best([(60, 12), (62.5, 9), (62.5, 8)])?.reps, 9)
        XCTAssertNil(FreeSessionText.best([]))
    }
}
