import XCTest
@testable import PernoCore

final class TimedSetTests: XCTestCase {
    override func setUp() {
        Units.unit = .kilograms
        Units.step = PlateStep.standard
    }

    func testPlan() {
        let sets = TimedPlan.sets(count: 3, weight: 10)
        XCTAssertEqual(sets.count, 3)
        XCTAssertTrue(sets.allSatisfy { $0.kind == .work && $0.weight == 10 && $0.reps == 0 })
        XCTAssertEqual(TimedPlan.sets(count: 2, weight: -5).map(\.weight), [0, 0])
        XCTAssertTrue(TimedPlan.sets(count: 0, weight: 10).isEmpty)
    }

    func testValue() {
        XCTAssertEqual(TimedText.value(seconds: 45, weight: 10), "10 × 0:45")
        XCTAssertEqual(TimedText.value(seconds: 45, weight: 12.5), "12,5 × 0:45")
        XCTAssertEqual(TimedText.value(seconds: 90, weight: nil), "1:30")
    }

    func testHeaderAndDock() {
        XCTAssertEqual(TimedText.exerciseHeader(position: 5, count: 5, sets: 3, seconds: 45),
                       "Esercizio 5 di 5, 3 set da 0:45")
        XCTAssertEqual(TimedText.inProgress(.work, 1), "Set 1 in corso, mancano")
        XCTAssertEqual(TimedText.of(seconds: 45), "di 0:45")
    }

    func testRemainingAndProgress() {
        XCTAssertEqual(TimedText.remaining(elapsed: 0, target: 45), "0:45")
        XCTAssertEqual(TimedText.remaining(elapsed: 0.3, target: 45), "0:45")
        XCTAssertEqual(TimedText.remaining(elapsed: 14, target: 45), "0:31")
        XCTAssertEqual(TimedText.remaining(elapsed: 50, target: 45), "0:00")
        XCTAssertEqual(TimedText.progress(elapsed: 0, target: 45), 0)
        XCTAssertEqual(TimedText.progress(elapsed: 22.5, target: 45), 0.5)
        XCTAssertEqual(TimedText.progress(elapsed: 60, target: 45), 1)
    }

    func testSecondsDone() {
        XCTAssertEqual(TimedText.secondsDone(duration: 38.4, target: 45), 38)
        XCTAssertEqual(TimedText.secondsDone(duration: 45.2, target: 45), 45)
        XCTAssertEqual(TimedText.secondsDone(duration: 120, target: 45), 45)
        XCTAssertEqual(TimedText.secondsDone(duration: -1, target: 45), 0)
    }

    func testNotice() {
        XCTAssertEqual(TimedText.noticeTitle(.work, 1, weight: 10), "Set 1, 10 ×")
        XCTAssertEqual(TimedText.noticeTitle(.work, 2, weight: nil), "Set 2")
        XCTAssertEqual(TimedText.noticeDetail(seconds: 45, target: 45), "A zero il set si chiude da solo.")
        XCTAssertEqual(TimedText.noticeDetail(seconds: 38, target: 45),
                       "Chiuso prima dello zero: salvato il tempo fatto. −/+ di 5 s.")
        XCTAssertEqual(TimedText.doneNote(seconds: 45, target: 45), "pieno")
        XCTAssertEqual(TimedText.doneNote(seconds: 38, target: 45), "di 0:45")
    }

    func testParse() {
        XCTAssertEqual(TimedText.parse("45"), 45)
        XCTAssertEqual(TimedText.parse("0:45"), 45)
        XCTAssertEqual(TimedText.parse(" 1:30 "), 90)
        XCTAssertEqual(TimedText.parse("2"), 5)
        XCTAssertNil(TimedText.parse("1:75"))
        XCTAssertNil(TimedText.parse("abc"))
        XCTAssertNil(TimedText.parse("0"))
    }
}
