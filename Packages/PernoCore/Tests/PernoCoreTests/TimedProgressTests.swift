import XCTest
@testable import PernoCore

final class TimedProgressTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        Units.unit = .kilograms
        Units.step = PlateStep.standard
    }

    func testProgression() {
        XCTAssertEqual(TimedProgression.target(base: 45, last: []), 45)
        let held = [TimedSet(target: 45, seconds: 45), TimedSet(target: 45, seconds: 45)]
        XCTAssertEqual(TimedProgression.target(base: 45, last: held), 50)
        let missed = [TimedSet(target: 50, seconds: 50), TimedSet(target: 50, seconds: 38)]
        XCTAssertEqual(TimedProgression.target(base: 45, last: missed), 50)
        // La scheda alzata a mano vince sulla volta prima.
        XCTAssertEqual(TimedProgression.target(base: 60, last: held), 60)
        XCTAssertEqual(TimedProgression.target(base: 600, last: [TimedSet(target: 600, seconds: 600)]), 600)
    }

    func testDeltaAndBefore() {
        XCTAssertEqual(TimedText.delta(today: 45, before: 40), "+5 s")
        XCTAssertEqual(TimedText.delta(today: 40, before: 45), "−5 s")
        XCTAssertNil(TimedText.delta(today: 45, before: 45))
        XCTAssertEqual(TimedText.before(seconds: 40, weight: 10), "prima 10 × 0:40")
        XCTAssertEqual(TimedText.before(seconds: 40, weight: nil), "prima 0:40")
    }

    func testTimedRecord() {
        let today = [TimedSet(target: 50, seconds: 55, weight: 10), TimedSet(target: 50, seconds: 50, weight: 10)]
        let record = SessionSummary.timedRecord(exercise: "Plank", today: today,
                                                previous: [TimedSet(target: 45, seconds: 50)], withWeight: true)
        XCTAssertEqual(record?.seconds, 55)
        XCTAssertEqual(record?.detail, "10 × 0:55, durata più lunga")
        XCTAssertEqual(record?.title, "Record su Plank")
        XCTAssertNil(SessionSummary.timedRecord(exercise: "Plank", today: today, previous: [], withWeight: true))
        XCTAssertNil(SessionSummary.timedRecord(exercise: "Plank", today: today,
                                                previous: [TimedSet(target: 60, seconds: 60)], withWeight: true))
        let noWeight = SessionSummary.timedRecord(exercise: "Plank", today: [TimedSet(target: 45, seconds: 45)],
                                                  previous: [TimedSet(target: 40, seconds: 40)], withWeight: false)
        XCTAssertEqual(noWeight?.detail, "0:45, durata più lunga")
    }

    func testKilogramsExcludeTimed() {
        let sets: [(kind: SetKind, weight: Double, reps: Int, timed: Bool)] = [
            (.work, 60, 10, false), (.approach, 30, 10, false), (.work, 10, 1, true),
        ]
        XCTAssertEqual(SessionSummary.liftedKilogramsExcludingTimed(sets), 600)
    }

    func testLiveActivityTimedSet() {
        let input = LiveActivityInput(phase: .inSet(since: t0), routine: "Upper body", exercise: "Plank",
                                      exerciseWorkSets: 3, setKind: .work, setNumber: 1, weight: 10, reps: 0,
                                      restMode: .stopwatch, restDuration: 90, restLabel: "Recupero",
                                      countdownSeconds: 3, canPostpone: false, awaitingChoice: false,
                                      sessionStart: t0, workSetsDone: 0, workSetsTotal: 3,
                                      targetSeconds: 45, withWeight: true)
        let state = LiveActivityText.state(for: input, now: t0)
        XCTAssertEqual(state.tone, .inSet)
        XCTAssertEqual(state.label, "Set 1 in corso, mancano")
        XCTAssertEqual(state.setValue, "10 × 0:45")
        XCTAssertEqual(state.timerEnd, t0.addingTimeInterval(45))
        XCTAssertTrue(state.showsProgress)
        XCTAssertEqual(state.primary, LiveActivityButton("Set 1 fatto", .setDone))
        // Il set a tempo non manda la notifica «Recupero finito».
        XCTAssertNil(LiveActivityText.nextChange(for: input, now: t0))

        var noWeight = input
        noWeight.withWeight = false
        noWeight.phase = .rest(since: t0)
        XCTAssertEqual(LiveActivityText.state(for: noWeight, now: t0).setValue, "0:45")
    }
}
