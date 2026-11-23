import XCTest
@testable import PernoCore

final class ResumeTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 50_000)

    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    private func plan() -> [PlannedExercise] {
        [
            PlannedExercise(name: "A", sets: [PlannedSet(kind: .approach, weight: 30, reps: 10),
                                              PlannedSet(kind: .work, weight: 60, reps: 10),
                                              PlannedSet(kind: .work, weight: 60, reps: 10)]),
            PlannedExercise(name: "B", sets: [PlannedSet(kind: .work, weight: 40, reps: 12)]),
            PlannedExercise(name: "C", sets: [PlannedSet(kind: .work, weight: 20, reps: 12)]),
        ]
    }

    private func done(_ exercise: Int, _ set: Int, ending seconds: TimeInterval) -> CompletedSet {
        CompletedSet(exerciseIndex: exercise, setIndex: set, kind: .work, weight: 60, reps: 10,
                     startedAt: at(seconds - 30), endedAt: at(seconds))
    }

    func testResumesWithRestOnTheSameExercise() {
        let session = SessionMachine(resuming: plan(), completed: [done(0, 1, ending: 200), done(0, 0, ending: 100)],
                                     pauses: [], at: at(1_000))
        XCTAssertEqual(session.phase, .rest(since: at(1_000)))
        XCTAssertEqual(session.currentExerciseIndex, 0)
        XCTAssertEqual(session.setIndex, 2)
        XCTAssertEqual(session.completedSets.map(\.setIndex), [0, 1])
    }

    func testResumesWithChangeoverOnTheNextExercise() throws {
        var session = SessionMachine(resuming: plan(), completed: [done(0, 2, ending: 300)], pauses: [], at: at(1_000))
        XCTAssertEqual(session.phase, .changeover(since: at(1_000)))
        XCTAssertEqual(session.currentExerciseIndex, 1)
        XCTAssertEqual(session.setIndex, 0)

        try session.start(at: at(1_010))
        try session.countdownFinished(at: at(1_013))
        try session.setDone(at: at(1_050))
        XCTAssertEqual(session.currentExerciseIndex, 2)
    }

    func testResumesFromTheStartOrFinished() {
        let fresh = SessionMachine(resuming: plan(), completed: [], pauses: [], at: at(10))
        XCTAssertEqual(fresh.phase, .changeover(since: at(10)))
        XCTAssertEqual(fresh.currentExerciseIndex, 0)

        let finished = SessionMachine(resuming: plan(), completed: [done(2, 0, ending: 500)], pauses: [], at: at(900))
        XCTAssertEqual(finished.phase, .finished)
    }

    func testTexts() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let closed = Date(timeIntervalSince1970: 18 * 3600 + 24 * 60)
        XCTAssertEqual(ResumeText.interrupted(at: closed, done: 7, total: 14, calendar: calendar),
                       "L'app si è chiusa alle 18:24. Avevi fatto 7 set su 14; tutto è salvato fino all'ultimo «Set fatto».")
        XCTAssertEqual(ResumeText.inProgress(done: 7, total: 14), "Hai fatto 7 set su 14.")
        XCTAssertEqual(ResumeText.summary([
            ExerciseProgress(name: "Chest press", done: 3, total: 3),
            ExerciseProgress(name: "Lat machine", done: 1, total: 3),
            ExerciseProgress(name: "Shoulder press", done: 0, total: 3),
            ExerciseProgress(name: "Pulley basso", done: 0, total: 3),
        ]), "Chest press fatto, Lat machine 1 di 3, poi Shoulder press")
        XCTAssertEqual(ResumeText.summary([ExerciseProgress(name: "Chest press", done: 0, total: 3)]),
                       "Da iniziare: Chest press")
        XCTAssertEqual(ExerciseProgress(name: "X", done: 0, total: 0).state, .notStarted)
    }
}
