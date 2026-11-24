import XCTest
@testable import PernoCore

final class RoutineSummaryTests: XCTestCase {
    func testWeekdayNames() {
        XCTAssertEqual(Weekday.all.map(Weekday.name),
                       ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"])
        XCTAssertEqual(Weekday.name(0), "")
        XCTAssertEqual(Weekday.name(8), "")
    }

    func testEstimate() {
        let five = Array(repeating: RoutineSummary.Entry(sets: 3), count: 5)
        // 15 set × (1:00 + 2:00) + 4 cambi × 1:30 = 51:00 → 50 minuti.
        XCTAssertEqual(RoutineSummary.estimatedDuration(five), 3060)
        XCTAssertEqual(RoutineSummary.estimatedMinutes(five), 50)

        // Recupero fissato e avvicinamenti: 3 × (60 + 90) + 2 × (45 + 60) = 11:00 → 10 minuti.
        let one = [RoutineSummary.Entry(sets: 3, approaches: 2, fixedRest: 90)]
        XCTAssertEqual(RoutineSummary.estimatedMinutes(one), 10)

        // Il recupero abituale sostituisce i 2 minuti di default, non quello fissato.
        XCTAssertEqual(RoutineSummary.estimatedDuration([RoutineSummary.Entry(sets: 2)], usualRest: 60), 240)
        XCTAssertEqual(RoutineSummary.estimatedDuration(one, usualRest: 60), 660)

        XCTAssertEqual(RoutineSummary.estimatedDuration([]), 0)
        XCTAssertEqual(RoutineSummary.estimatedMinutes([RoutineSummary.Entry(sets: 1)]), 5)
    }

    func testText() {
        XCTAssertEqual(RoutineSummary.text([]), "Nessun esercizio")
        XCTAssertEqual(RoutineSummary.text([RoutineSummary.Entry(sets: 3, approaches: 2, fixedRest: 90)]),
                       "1 esercizio, circa 10 minuti")
        XCTAssertEqual(RoutineSummary.text(Array(repeating: RoutineSummary.Entry(sets: 3, approaches: 1), count: 4)),
                       "4 esercizi, circa 50 minuti")
    }
}
