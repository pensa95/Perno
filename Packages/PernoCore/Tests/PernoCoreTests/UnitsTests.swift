import XCTest
@testable import PernoCore

final class UnitsTests: XCTestCase {
    override func tearDown() {
        Units.unit = .kilograms
        Units.step = PlateStep.standard
        super.tearDown()
    }

    func testDefaultsAreKilogramsAndTwoAndAHalf() {
        XCTAssertEqual(Units.unit, .kilograms)
        XCTAssertEqual(PlateStep.current, 2.5)
        XCTAssertEqual(Units.show(62.5), "62,5")
        XCTAssertEqual(Units.summary(unit: .kilograms, step: 2.5), "Chili, passo 2,5")
    }

    func testPoundsAreOnlyADisplayFormat() {
        Units.unit = .pounds
        let saved = WeightUnit.pounds.toKilograms(135)
        XCTAssertEqual(saved, 61.234969950, accuracy: 0.000001)
        XCTAssertEqual(Units.show(saved), "135")
        XCTAssertEqual(Units.show(60), "132,28")
        XCTAssertEqual(SessionText.weightReps(saved, 10), "135 × 10")
        XCTAssertEqual(SessionText.delta(today: WeightUnit.pounds.toKilograms(140), before: saved), "+5 lb")
        XCTAssertEqual(Units.summary(unit: .pounds, step: 5), "Libbre, passo 5")
    }

    func testPlateStepInPounds() {
        Units.unit = .pounds
        Units.step = 2.5
        XCTAssertEqual(PlateStep.current, 2.5 * WeightUnit.kilogramsPerPound, accuracy: 0.000001)
        let up = SetCorrection.stepWeight(WeightUnit.pounds.toKilograms(135), by: PlateStep.current)
        XCTAssertEqual(Units.show(up), "137,5")
        let typed = SetCorrection.parseWeight("100")
        XCTAssertEqual(Units.show(typed ?? 0), "100")
        // Un avvicinamento (60%) di 135 lb, arrotondato a 2,5 lb.
        let approach = Approach.weights(count: 1, workWeight: WeightUnit.pounds.toKilograms(135), step: PlateStep.current)
        XCTAssertEqual(approach.map(Units.show), ["80"])
    }

    func testExampleCard() {
        XCTAssertEqual(Units.example(step: 2.5).increase, "62,5 → 65")
        XCTAssertEqual(Units.example(step: 2.5).approach, "47,5")
        XCTAssertEqual(Units.example(step: 1).increase, "62,5 → 63,5")
        XCTAssertEqual(Units.example(step: 1).approach, "47")
        XCTAssertEqual(Units.example(step: 5).approach, "45")
        XCTAssertEqual(Units.example(step: 1.25).approach, "47,5")
    }

    func testRecordInPounds() {
        Units.unit = .pounds
        let record = SessionSummary.Record(exercise: "Panca", lift: .init(weight: WeightUnit.pounds.toKilograms(100), reps: 10))
        XCTAssertEqual(record.detail, "100 × 10, massimale stimato 133 lb")
    }
}
