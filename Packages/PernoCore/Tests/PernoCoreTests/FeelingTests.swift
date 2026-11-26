import XCTest
@testable import PernoCore

final class FeelingTests: XCTestCase {
    private func sets(_ feelings: [Feeling?], weight: Double = 60, reps: Int = 12) -> [Progression.WorkSet] {
        feelings.map { Progression.WorkSet(weight: weight, reps: reps, feeling: $0) }
    }

    private func decide(_ history: [[Progression.WorkSet]], workSets: Int = 3) -> Progression.Decision {
        Progression.decide(history: history, workSets: workSets, repsMin: 8, repsMax: 12, step: 2.5)
    }

    func testIncreaseNeedsNoHardAndHalfLight() {
        XCTAssertEqual(decide([sets([.light, .light, .justRight])]), .increase(to: 62.5))
        XCTAssertEqual(decide([sets([.light, .light, .light])]), .increase(to: 62.5))
        // Metà esatta: 2 leggeri su 4.
        XCTAssertEqual(decide([sets([.light, .justRight, .light, .justRight])], workSets: 4), .increase(to: 62.5))
        // Meno della metà leggeri: si mantiene.
        XCTAssertEqual(decide([sets([.light, .justRight, .justRight])]), .holdFeeling)
        XCTAssertEqual(decide([sets([.justRight, .justRight, .justRight])]), .holdFeeling)
    }

    func testOneHardHolds() {
        // Primo leggero e ultimo faticoso: non si alza (si guardano tutti i set).
        XCTAssertEqual(decide([sets([.light, .light, .hard])]), .holdFeeling)
        let planned = SessionPlanner.plan(workSets: 3, repsMin: 8, repsMax: 12, approaches: 0,
                                          history: [sets([.light, .light, .hard])], step: 2.5)
        XCTAssertEqual(planned.map(\.weight), [60, 60, 60])
    }

    func testFeelingsNeedRepsAtTop() {
        // Le faccine si aggiungono alla regola delle ripetizioni: senza il massimo non si aumenta.
        let history = [[Progression.WorkSet(weight: 60, reps: 12, feeling: .light),
                        Progression.WorkSet(weight: 60, reps: 11, feeling: .light),
                        Progression.WorkSet(weight: 60, reps: 12, feeling: .light)]]
        XCTAssertEqual(decide(history), .repeatLast)
    }

    func testMissingFeelingsCountAsNotLight() {
        // Faccine solo su alcuni set: i set senza faccina non sono leggeri.
        XCTAssertEqual(decide([sets([.light, nil, nil])]), .holdFeeling)
        XCTAssertEqual(decide([sets([.light, .light, nil])]), .increase(to: 62.5))
    }

    func testWithoutFeelingsOldRuleApplies() {
        let zero = [[Progression.WorkSet(weight: 60, reps: 12, reserve: 0),
                     Progression.WorkSet(weight: 60, reps: 12, reserve: 0)]]
        XCTAssertEqual(decide(zero, workSets: 2), .holdNoReserve)
        XCTAssertEqual(decide([sets([nil, nil, nil])]), .increase(to: 62.5))
    }

    func testNoticeTexts() {
        let unitaPrima = Units.unit
        Units.unit = .kilograms
        defer { Units.unit = unitaPrima }
        XCTAssertEqual(NoticeText.title(.work, 1, weight: 65), "Set 1 fatto, 65 kg")
        XCTAssertEqual(NoticeText.title(.work, 2, weight: 12.5), "Set 2 fatto, 12,5 kg")
        XCTAssertEqual(NoticeText.title(.approach, 1, weight: 30), "Avv. 1 fatto, 30 kg")
        XCTAssertEqual(NoticeText.title(.work, 3, weight: nil), "Set 3 fatto")
        XCTAssertEqual(NoticeText.repsDelta(done: 13, target: 10), "+3 sull'obiettivo")
        XCTAssertEqual(NoticeText.repsDelta(done: 9, target: 10), "−1 sull'obiettivo")
        XCTAssertEqual(NoticeText.repsDelta(done: 10, target: 10), "come l'obiettivo")
        XCTAssertEqual(NoticeText.duration, 10)
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(NoticeText.remaining(until: now.addingTimeInterval(7), now: now), 0.7, accuracy: 0.0001)
        XCTAssertEqual(NoticeText.remaining(until: now.addingTimeInterval(-1), now: now), 0)
        XCTAssertEqual(NoticeText.remaining(until: now.addingTimeInterval(30), now: now), 1)
        XCTAssertEqual(Feeling.hard.word, "faticoso")
    }
}
