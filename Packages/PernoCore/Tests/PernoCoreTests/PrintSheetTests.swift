import XCTest
@testable import PernoCore

final class PrintSheetTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 18))!
    }

    func testTargets() {
        XCTAssertEqual(PrintText.repsTarget(min: 8, max: 12), "8–12")
        XCTAssertEqual(PrintText.repsTarget(min: 10, max: 10), "10")
        let rows = PrintText.routineRows(sets: 3, repsMin: 8, repsMax: 12, approaches: 2)
        XCTAssertEqual(rows.map(\.label), ["Avv. 1", "Avv. 2", "Set 1", "Set 2", "Set 3"])
        XCTAssertEqual(rows.map(\.target), ["50%", "75%", "8–12", "8–12", "8–12"])
        XCTAssertEqual(rows.map(\.isApproach), [true, true, false, false, false])
        XCTAssertTrue(rows.allSatisfy { $0.weight.isEmpty && $0.reps.isEmpty && $0.reserve.isEmpty })
    }

    func testSessionRow() {
        let done = PrintText.sessionRow(kind: .work, number: 2, target: "8–12", done: true,
                                        weight: "62,5", reps: 10, reserve: .fourOrMore)
        XCTAssertEqual(done, PrintRow(label: "Set 2", target: "8–12", weight: "62,5", reps: "10",
                                      reserve: "4+", isApproach: false))
        let undone = PrintText.sessionRow(kind: .work, number: 3, target: "8–12", done: false,
                                          weight: nil, reps: nil, reserve: nil)
        XCTAssertEqual(undone.weight, "—")
        XCTAssertEqual(undone.reps, "—")
        XCTAssertEqual(undone.reserve, "")
    }

    func testLinesAndFooter() {
        XCTAssertEqual(PrintText.sessionLines(when: "Martedì 24 novembre, dalle 18:04 alle 19:03",
                                              duration: "58:10", setsDone: 14, setsPlanned: 16,
                                              volume: "4.230", unit: "kg"),
                       ["Martedì 24 novembre, dalle 18:04 alle 19:03",
                        "Durata 58:10 · 14/16 set · 4.230 kg sollevati"])
        XCTAssertEqual(PrintText.footer(exportedAt: date(2026, 11, 24), calendar: calendar),
                       "Perno · esportato il 24 novembre 2026")
        XCTAssertEqual(PrintText.fileName(title: "Upper/body", date: date(2026, 3, 5), calendar: calendar),
                       "Upper-body 05-03-2026.pdf")
        XCTAssertEqual(PrintSheet.columns(unit: "kg"), ["Set", "Obiettivo", "Peso (kg)", "Ripetizioni", "Riserva"])
    }
}
