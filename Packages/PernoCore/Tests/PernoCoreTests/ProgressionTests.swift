import XCTest
@testable import PernoCore

final class ProgressionTests: XCTestCase {
    private func sets(_ values: [(Double, Int)], reserve: Int? = nil) -> [Progression.WorkSet] {
        values.map { Progression.WorkSet(weight: $0.0, reps: $0.1, reserve: reserve) }
    }

    func testIncreaseWhenAllSetsAtTopOfRange() {
        let history = [sets([(60, 12), (60, 12), (60, 12)], reserve: 1)]
        XCTAssertEqual(Progression.decide(history: history, workSets: 3, repsMin: 8, repsMax: 12, step: 2.5),
                       .increase(to: 62.5))
        let planned = SessionPlanner.plan(workSets: 3, repsMin: 8, repsMax: 12, approaches: 2,
                                          history: history, step: 2.5)
        XCTAssertEqual(planned.filter { $0.kind == .work }.map(\.weight), [62.5, 62.5, 62.5])
        XCTAssertEqual(planned.filter { $0.kind == .work }.map(\.reps), [8, 8, 8])
        // Avvicinamenti dal peso nuovo: 50% e 75% di 62,5 arrotondati a 2,5.
        XCTAssertEqual(planned.filter { $0.kind == .approach }.map(\.weight), [32.5, 47.5])
    }

    func testNoIncreaseWhenOneSetMissesTopOrSetsAreMissing() {
        let short = [sets([(60, 12), (60, 11), (60, 12)])]
        XCTAssertEqual(Progression.decide(history: short, workSets: 3, repsMin: 8, repsMax: 12, step: 2.5), .repeatLast)
        let fewer = [sets([(60, 12), (60, 12)])]
        XCTAssertEqual(Progression.decide(history: fewer, workSets: 3, repsMin: 8, repsMax: 12, step: 2.5), .repeatLast)
        let lighterLast = [sets([(60, 12), (60, 12), (57.5, 12)])]
        XCTAssertEqual(Progression.decide(history: lighterLast, workSets: 3, repsMin: 8, repsMax: 12, step: 2.5), .repeatLast)
    }

    func testReserveZeroHolds() {
        let history = [sets([(60, 12), (60, 12)], reserve: 0)]
        XCTAssertEqual(Progression.decide(history: history, workSets: 2, repsMin: 8, repsMax: 12, step: 2.5),
                       .holdNoReserve)
        // Una sola riserva sopra 0 basta per aumentare; senza riserve si aumenta.
        var mixed = history
        mixed[0][1].reserve = 1
        XCTAssertEqual(Progression.decide(history: mixed, workSets: 2, repsMin: 8, repsMax: 12, step: 2.5),
                       .increase(to: 62.5))
        XCTAssertEqual(Progression.decide(history: [sets([(60, 12), (60, 12)])], workSets: 2, repsMin: 8,
                                          repsMax: 12, step: 2.5), .increase(to: 62.5))
        let held = SessionPlanner.plan(workSets: 2, repsMin: 8, repsMax: 12, approaches: 0, history: history, step: 2.5)
        XCTAssertEqual(held.map(\.weight), [60, 60])
        XCTAssertEqual(held.map(\.reps), [12, 12])
    }

    func testBelowMinimumOnceHoldsTwiceDeloads() {
        let once = [sets([(60, 8), (60, 7)]), sets([(60, 9), (60, 8)])]
        XCTAssertEqual(Progression.decide(history: once, workSets: 2, repsMin: 8, repsMax: 12, step: 2.5), .repeatLast)
        let twice = [sets([(60, 8), (60, 7)]), sets([(60, 8), (60, 6)])]
        XCTAssertEqual(Progression.decide(history: twice, workSets: 2, repsMin: 8, repsMax: 12, step: 2.5),
                       .deload(to: 55))
        let planned = SessionPlanner.plan(workSets: 2, repsMin: 8, repsMax: 12, approaches: 0, history: twice, step: 2.5)
        XCTAssertEqual(planned, [PlannedSet(kind: .work, weight: 55, reps: 8), PlannedSet(kind: .work, weight: 55, reps: 8)])
    }

    func testFirstTime() {
        XCTAssertEqual(Progression.decide(history: [], workSets: 3, repsMin: 8, repsMax: 12, step: 2.5), .firstTime)
        let planned = SessionPlanner.plan(workSets: 2, repsMin: 8, repsMax: 12, approaches: 0, history: [], step: 2.5)
        XCTAssertEqual(planned.map(\.reps), [8, 8])
        XCTAssertEqual(planned.map(\.weight), [0, 0])
    }

    func testDeloadAdvice() {
        let advice = ExerciseHistory.deloadAdvice(weeks: 3, lastWeight: 60, step: 2.5)
        XCTAssertEqual(advice.title, "Fermo da 3 settimane")
        XCTAssertTrue(advice.detail.contains("55"))
        XCTAssertEqual(ExerciseHistory.deloadAdvice(weeks: 4, lastWeight: 0, step: 2.5).detail,
                       "Prova una settimana di scarico, con meno peso, poi riparti.")
    }
}
