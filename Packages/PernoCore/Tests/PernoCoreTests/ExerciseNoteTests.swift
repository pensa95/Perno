import XCTest
@testable import PernoCore

final class ExerciseNoteTests: XCTestCase {
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }

    private func data(_ giorno: Int, _ mese: Int) -> Date {
        calendario.date(from: DateComponents(year: 2026, month: mese, day: giorno, hour: 18))!
    }

    func testLabels() {
        XCTAssertEqual(ExerciseNoteText.lastTime(data(19, 11), calendar: calendario), "Nota della volta scorsa, 19 nov")
        XCTAssertEqual(ExerciseNoteText.lastTime(data(3, 6), calendar: calendario), "Nota della volta scorsa, 3 giu")
        XCTAssertEqual(ExerciseNoteText.today, "Nota di oggi, la ritrovi la prossima volta")
    }

    func testOnlyTheLastTimeCounts() {
        let volte = [(date: data(12, 11), note: "Alza il peso"), (date: data(19, 11), note: "  Sedile 5 \n")]
        let nota = ExerciseNoteText.lastNote(volte)
        XCTAssertEqual(nota?.note, "Sedile 5")
        XCTAssertEqual(nota?.date, data(19, 11))
        // L'ultima volta senza nota: niente, anche se prima c'era.
        XCTAssertNil(ExerciseNoteText.lastNote([(date: data(12, 11), note: "Alza il peso"), (date: data(19, 11), note: "")]))
        XCTAssertNil(ExerciseNoteText.lastNote([]))
    }
}
