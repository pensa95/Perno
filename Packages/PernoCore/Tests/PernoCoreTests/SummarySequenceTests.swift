import XCTest
@testable import PernoCore

final class SummarySequenceTests: XCTestCase {
    func testStepsAndDuration() {
        XCTAssertEqual(SummarySequence.steps(records: 0), 3)
        XCTAssertEqual(SummarySequence.steps(records: 2), 5)
        XCTAssertEqual(SummarySequence.steps(records: -1), 3)
        XCTAssertEqual(SummarySequence.duration(records: 0), 1.65, accuracy: 0.0001)
    }

    func testEachStepStartsWhenThePreviousEnds() {
        // A metà del primo passo i set non sono ancora partiti.
        XCTAssertGreaterThan(SummarySequence.fraction(progress: 0.5, step: 0), 0)
        XCTAssertEqual(SummarySequence.fraction(progress: 0.5, step: 1), 0)
        // Finito il primo passo, la durata è piena e i set partono.
        XCTAssertEqual(SummarySequence.fraction(progress: 1, step: 0), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(SummarySequence.fraction(progress: 1.5, step: 1), 0)
        XCTAssertEqual(SummarySequence.fraction(progress: 1.5, step: 2), 0)
        // Alla fine tutto è pieno, e oltre non va.
        XCTAssertEqual(SummarySequence.fraction(progress: 5, step: 4), 1, accuracy: 0.0001)
        XCTAssertEqual(SummarySequence.fraction(progress: 9, step: 0), 1, accuracy: 0.0001)
    }
}
