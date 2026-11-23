import XCTest
@testable import PernoCore

final class SessionPlannerTests: XCTestCase {
    func testApproachReps() {
        XCTAssertEqual(SessionPlanner.approachReps(count: 0), [])
        XCTAssertEqual(SessionPlanner.approachReps(count: 2), [10, 6])
        XCTAssertEqual(SessionPlanner.approachReps(count: 3).count, 3)
    }

    /// Come la tavola: lavoro a 60 kg l'ultima volta, 2 avvicinamenti → 30 × 10 e 45 × 6.
    func testPlanFromPreviousSession() {
        let sets = SessionPlanner.plan(workSets: 3, repsMin: 8, approaches: 2,
                                       previous: [(60, 10), (60, 10), (57.5, 9)], step: 2.5)
        XCTAssertEqual(sets, [
            PlannedSet(kind: .approach, weight: 30, reps: 10),
            PlannedSet(kind: .approach, weight: 45, reps: 6),
            PlannedSet(kind: .work, weight: 60, reps: 10),
            PlannedSet(kind: .work, weight: 60, reps: 10),
            PlannedSet(kind: .work, weight: 60, reps: 9),
        ])
    }

    func testMoreSetsThanLastTimeRepeatLastReps() {
        let sets = SessionPlanner.plan(workSets: 3, repsMin: 8, approaches: 0,
                                       previous: [(40, 12)], step: 2.5)
        XCTAssertEqual(sets.map(\.reps), [12, 12, 12])
        XCTAssertTrue(sets.allSatisfy { $0.kind == .work && $0.weight == 40 })
    }

    func testFirstTimeUsesMinimumAndNoWeight() {
        let sets = SessionPlanner.plan(workSets: 2, repsMin: 8, approaches: 1, previous: [], step: 2.5)
        XCTAssertEqual(sets, [
            PlannedSet(kind: .approach, weight: 0, reps: 8),
            PlannedSet(kind: .work, weight: 0, reps: 8),
            PlannedSet(kind: .work, weight: 0, reps: 8),
        ])
    }

    func testApproachWeightsRoundToPlateStep() {
        // 62,5 × 60% = 37,5; × 40% = 25; × 80% = 50 (passo 2,5).
        let sets = SessionPlanner.plan(workSets: 1, repsMin: 8, approaches: 3,
                                       previous: [(62.5, 8)], step: 2.5)
        XCTAssertEqual(sets.prefix(3).map(\.weight), [25, 37.5, 50])
    }
}
