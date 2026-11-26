import XCTest
@testable import PernoCore

final class LiveActivityTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        Units.unit = .kilograms
        Units.step = PlateStep.standard
    }

    private func input(_ phase: SessionPhase, mode: RestMode = .stopwatch, exercise: String? = "Chest press",
                       kind: SetKind = .work, number: Int = 2, canPostpone: Bool = false,
                       awaitingChoice: Bool = false) -> LiveActivityInput {
        LiveActivityInput(phase: phase, routine: "Upper body", exercise: exercise, exerciseWorkSets: 3,
                          setKind: kind, setNumber: number, weight: 62.5, reps: 10, restMode: mode,
                          restDuration: 130, restLabel: "Recupero, di solito 2:10", countdownSeconds: 3,
                          canPostpone: canPostpone, awaitingChoice: awaitingChoice, sessionStart: t0,
                          workSetsDone: 14, workSetsTotal: 14)
    }

    func testWarmUp() {
        let state = LiveActivityText.state(for: input(.warmUp(since: t0)), now: t0)
        XCTAssertEqual(state.tone, .warmUp)
        XCTAssertEqual(state.label, "Riscaldamento in corso")
        XCTAssertEqual(state.title, "Poi Chest press")
        XCTAssertEqual(state.setLabel, "3 set")
        XCTAssertNil(state.setValue)
        XCTAssertEqual(state.primary, LiveActivityButton("Riscaldamento fatto", .endWarmUp))
        XCTAssertEqual(state.secondary, LiveActivityButton("Salta", .skipWarmUp))
        XCTAssertNil(state.timerEnd)
    }

    func testChangeoverWithPostpone() {
        let state = LiveActivityText.state(for: input(.changeover(since: t0), kind: .approach, number: 1,
                                                      canPostpone: true), now: t0)
        XCTAssertEqual(state.tone, .changeover)
        XCTAssertEqual(state.label, "Cambio esercizio")
        XCTAssertEqual(state.setLabel, "Avv. 1")
        XCTAssertEqual(state.setValue, "62,5 × 10")
        XCTAssertEqual(state.primary, LiveActivityButton("Inizia avvicinamento 1", .start))
        XCTAssertEqual(state.secondary, LiveActivityButton("Rimanda", .postpone))
    }

    func testFreeSessionAwaitingChoice() {
        let state = LiveActivityText.state(for: input(.changeover(since: t0), exercise: nil, awaitingChoice: true),
                                           now: t0)
        XCTAssertEqual(state.title, "Nessun esercizio")
        XCTAssertEqual(state.setLabel, "Sessione libera")
        XCTAssertEqual(state.primary, LiveActivityButton("Scegli esercizi", .open))
        XCTAssertNil(state.secondary)
    }

    func testCountdownKeepsRestColour() {
        let since = t0.addingTimeInterval(100)
        let state = LiveActivityText.state(
            for: input(.countdown(since: since, pauseStart: t0, pauseKind: .rest)), now: since)
        XCTAssertEqual(state.tone, .rest)
        XCTAssertEqual(state.label, "Set 2 tra")
        XCTAssertEqual(state.timerEnd, Countdown.end(since: since))
        XCTAssertTrue(state.bigTimer)
        XCTAssertNil(state.primary)

        let fromChangeover = LiveActivityText.state(
            for: input(.countdown(since: since, pauseStart: t0, pauseKind: .changeover)), now: since)
        XCTAssertEqual(fromChangeover.tone, .changeover)
    }

    func testInSet() {
        let state = LiveActivityText.state(for: input(.inSet(since: t0)), now: t0)
        XCTAssertEqual(state.tone, .inSet)
        XCTAssertEqual(state.label, "Set 2 in corso")
        XCTAssertEqual(state.setLabel, "Set 2, obiettivo")
        XCTAssertEqual(state.primary, LiveActivityButton("Set 2 fatto", .setDone))
        XCTAssertNil(state.secondary)
    }

    func testRestStopwatch() {
        let state = LiveActivityText.state(for: input(.rest(since: t0)), now: t0.addingTimeInterval(500))
        XCTAssertEqual(state.label, "Recupero, di solito 2:10")
        XCTAssertNil(state.timerEnd)
        XCTAssertFalse(state.showsProgress)
        XCTAssertEqual(state.primary, LiveActivityButton("Inizia set 2", .start))
        XCTAssertNil(state.secondary)
        XCTAssertNil(LiveActivityText.nextChange(for: input(.rest(since: t0)), now: t0))
    }

    func testRestCountdownThenOvertime() {
        let rest = input(.rest(since: t0), mode: .countdown)
        let running = LiveActivityText.state(for: rest, now: t0.addingTimeInterval(60))
        XCTAssertEqual(running.timerEnd, t0.addingTimeInterval(130))
        XCTAssertTrue(running.showsProgress)
        XCTAssertNil(running.timerPrefix)
        XCTAssertEqual(running.secondary, LiveActivityButton("+15 s", .addFifteen))
        XCTAssertEqual(LiveActivityText.nextChange(for: rest, now: t0), t0.addingTimeInterval(130))

        let over = LiveActivityText.state(for: rest, now: t0.addingTimeInterval(142))
        XCTAssertEqual(over.label, "Recupero finito, tempo in più")
        XCTAssertEqual(over.timerPrefix, "+")
        XCTAssertNil(over.secondary)
        XCTAssertEqual(over.primary, LiveActivityButton("Inizia set 2", .start))
        XCTAssertNil(LiveActivityText.nextChange(for: rest, now: t0.addingTimeInterval(142)))
    }

    func testFinished() {
        let state = LiveActivityText.state(for: input(.finished), now: t0)
        XCTAssertEqual(state.tone, .finished)
        XCTAssertEqual(state.label, "Tutti i set fatti")
        XCTAssertEqual(state.title, "Upper body")
        XCTAssertEqual(state.setLabel, "14 set su 14")
        XCTAssertEqual(state.timerStart, t0)
        XCTAssertEqual(state.primary, LiveActivityButton("Vai al riepilogo", .open))
    }

    func testRestOverBody() {
        XCTAssertEqual(LiveActivityText.restOverBody(setName: "Set 2", exercise: "Chest press", value: "62,5 × 10"),
                       "Set 2 di Chest press, 62,5 × 10.")
        XCTAssertEqual(LiveActivityText.restOverBody(setName: "Set 2", exercise: "Chest press", value: nil),
                       "Set 2 di Chest press.")
    }

    func testStateRoundTripsThroughJSON() throws {
        let state = LiveActivityText.state(for: input(.rest(since: t0), mode: .countdown), now: t0)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(LiveActivityState.self, from: data), state)
    }
}

final class NextExerciseTests: XCTestCase {
    func testTexts() {
        XCTAssertEqual(NextExerciseText.detail(sets: 3, repsMin: 8, repsMax: 12), "3 set da 8 a 12")
        XCTAssertEqual(NextExerciseText.detail(sets: 4, repsMin: 10, repsMax: 10), "4 set da 10")
        XCTAssertEqual(NextExerciseText.detail(sets: 3, repsMin: 8, repsMax: 12, seconds: 45), "3 set da 0:45")
        XCTAssertEqual(NextExerciseText.subtitle(exercise: "Lat machine", detail: "3 set da 8 a 12"),
                       "Poi Lat machine, 3 set da 8 a 12")
        XCTAssertEqual(NextExerciseText.goTo("Lat machine"), "Vai a Lat machine")
    }

    func testCardOffersGoToNext() {
        let t0 = Date(timeIntervalSince1970: 1_000)
        let input = LiveActivityInput(phase: .changeover(since: t0), routine: "Upper body", exercise: "Lat machine",
                                      exerciseWorkSets: 3, setKind: .approach, setNumber: 1, weight: 30, reps: 10,
                                      restMode: .stopwatch, restDuration: 120, restLabel: "Recupero",
                                      countdownSeconds: 3, canPostpone: true, awaitingChoice: false,
                                      sessionStart: t0, workSetsDone: 3, workSetsTotal: 12,
                                      awaitingNext: true, nextDetail: "3 set da 8 a 12")
        let state = LiveActivityText.state(for: input, now: t0)
        XCTAssertEqual(state.tone, .changeover)
        XCTAssertEqual(state.label, "Cambio esercizio")
        XCTAssertEqual(state.title, "Poi Lat machine")
        XCTAssertEqual(state.setLabel, "3 set da 8 a 12")
        XCTAssertNil(state.setValue)
        XCTAssertEqual(state.timerStart, t0)
        XCTAssertEqual(state.primary, LiveActivityButton("Vai a Lat machine", .goToNext))
        XCTAssertNil(state.secondary)
    }
}
