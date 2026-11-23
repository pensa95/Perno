import XCTest
@testable import PernoCore

final class WeightsTests: XCTestCase {
    func testRoundToDiscStep() {
        XCTAssertEqual(Weights.round(46.875, step: 2.5), 47.5)
        XCTAssertEqual(Weights.round(31.25, step: 2.5), 32.5) // a metà strada: per eccesso
        XCTAssertEqual(Weights.round(30, step: 2.5), 30)
        XCTAssertEqual(Weights.round(61, step: 5), 60)
        XCTAssertEqual(Weights.round(10.6, step: 1.25), 10)
        XCTAssertEqual(Weights.round(11, step: 1.25), 11.25)
    }

    func testFormat() {
        XCTAssertEqual(Weights.format(62.5), "62,5")
        XCTAssertEqual(Weights.format(60), "60")
        XCTAssertEqual(Weights.format(1.25), "1,25")
    }

    func testApproachPercentages() {
        XCTAssertEqual(Approach.percentages(count: 0), [])
        XCTAssertEqual(Approach.percentages(count: 1), [0.60])
        XCTAssertEqual(Approach.percentages(count: 2), [0.50, 0.75])
        XCTAssertEqual(Approach.percentages(count: 3), [0.40, 0.60, 0.80])
        XCTAssertEqual(Approach.percentages(count: 4), [])
    }

    func testApproachWeightsMatchTheBoards() {
        // Tavole v3: Chest press, lavoro 60 kg, due avvicinamenti → 30 e 45.
        XCTAssertEqual(Approach.weights(count: 2, workWeight: 60, step: 2.5), [30, 45])
        // Unità e dischi: 75% di 62,5 con passo 2,5 → 47,5.
        XCTAssertEqual(Approach.weights(count: 2, workWeight: 62.5, step: 2.5), [32.5, 47.5])
    }
}
