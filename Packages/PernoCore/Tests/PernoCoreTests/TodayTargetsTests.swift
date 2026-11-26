import XCTest
@testable import PernoCore

final class TodayTargetsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    private func macchina() -> SessionMachine {
        SessionMachine(exercises: [
            PlannedExercise(name: "Chest press", sets: [PlannedSet(kind: .work, weight: 60, reps: 10)]),
            PlannedExercise(name: "Shoulder press", sets: [PlannedSet(kind: .approach, weight: 15, reps: 10),
                                                           PlannedSet(kind: .approach, weight: 22.5, reps: 6),
                                                           PlannedSet(kind: .work, weight: 30, reps: 8),
                                                           PlannedSet(kind: .work, weight: 30, reps: 8)]),
        ], warmUp: false, at: t0)
    }

    func testReadAndSummary() {
        let m = macchina()
        let obiettivi = m.todayTargets(exercise: 1)
        XCTAssertEqual(obiettivi, TodayTargets(sets: 2, weight: 30, reps: 8))
        let unita = Units.unit
        Units.unit = .kilograms
        defer { Units.unit = unita }
        XCTAssertEqual(TodayTargets(sets: 3, weight: 40, reps: 10).summary(), "3 × 40 × 10")
        XCTAssertEqual(TodayTargets(sets: 3, weight: 12.5, reps: 15).summary(), "3 × 12,5 × 15")
        XCTAssertEqual(TodayTargets(sets: 3, weight: 10, reps: 0).summary(seconds: 45), "3 × 10 × 0:45")
        XCTAssertEqual(TodayTargets(sets: 3, weight: 0, reps: 0).summary(seconds: 45, withWeight: false), "3 × 0:45")
    }

    func testSetTargetsAppliesToAllWorkSetsAndRecalculatesApproaches() throws {
        var m = macchina()
        try m.setTodayTargets(exercise: 1, targets: TodayTargets(sets: 3, weight: 40, reps: 10), step: 2.5)
        let sets = m.exercises[1].sets
        XCTAssertEqual(sets.map(\.kind), [.approach, .approach, .work, .work, .work])
        XCTAssertEqual(sets.filter { $0.kind == .work }.map(\.weight), [40, 40, 40])
        XCTAssertEqual(sets.filter { $0.kind == .work }.map(\.reps), [10, 10, 10])
        // Avvicinamenti: 50% e 75% di 40, arrotondati a 2,5; ripetizioni invariate.
        XCTAssertEqual(sets.filter { $0.kind == .approach }.map(\.weight), [20, 30])
        XCTAssertEqual(sets.filter { $0.kind == .approach }.map(\.reps), [10, 6])
        XCTAssertEqual(m.todayTargets(exercise: 1), TodayTargets(sets: 3, weight: 40, reps: 10))
    }

    func testOnlyBeforeStarting() throws {
        var m = macchina()
        XCTAssertTrue(m.canSetTodayTargets(exercise: 0))
        try m.start(at: t0)
        XCTAssertFalse(m.canSetTodayTargets(exercise: 0))
        XCTAssertTrue(m.canSetTodayTargets(exercise: 1))
        try m.countdownFinished(at: t0.addingTimeInterval(3))
        try m.setDone(at: t0.addingTimeInterval(40))
        // Chest press ha un set fatto: non si cambia più.
        XCTAssertFalse(m.canSetTodayTargets(exercise: 0))
        XCTAssertThrowsError(try m.setTodayTargets(exercise: 0, targets: TodayTargets(sets: 2, weight: 50, reps: 8),
                                                   step: 2.5))
        // Shoulder press è adesso, nel cambio esercizio: si cambia, e si parte dal primo set.
        XCTAssertEqual(m.currentExerciseIndex, 1)
        try m.setTodayTargets(exercise: 1, targets: TodayTargets(sets: 1, weight: 35, reps: 12), step: 2.5)
        XCTAssertEqual(m.setIndex, 0)
        XCTAssertEqual(m.exercises[1].sets.count, 3)
    }
}
