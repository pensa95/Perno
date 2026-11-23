import XCTest
@testable import PernoCore

final class RoutineEditingTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(Clock.text(150), "2:30")
        XCTAssertEqual(Clock.text(45), "0:45")
        XCTAssertEqual(Clock.text(600), "10:00")
        XCTAssertEqual(Clock.text(-3), "0:00")
    }

    func testRepRangeKeepsMinBelowMax() {
        XCTAssertEqual(EntryLimits.settingMin(10, max: 12).min, 10)
        XCTAssertEqual(EntryLimits.settingMin(13, max: 12).max, 13)
        XCTAssertEqual(EntryLimits.settingMin(0, max: 12).min, 1)
        XCTAssertEqual(EntryLimits.settingMax(7, min: 8).min, 7)
        XCTAssertEqual(EntryLimits.settingMax(60, min: 8).max, 50)
        XCTAssertEqual(EntryLimits.clamp(11, EntryLimits.sets), 10)
        XCTAssertEqual(EntryLimits.clamp(5, EntryLimits.rest), 15)
    }

    func testEntrySummary() {
        XCTAssertEqual(EntrySummary.text(sets: 3, repsMin: 8, repsMax: 12, approaches: 2, fixedRest: nil),
                       "3 set da 8 a 12, 2 avvicinamenti")
        XCTAssertEqual(EntrySummary.text(sets: 3, repsMin: 8, repsMax: 10, approaches: 1, fixedRest: 150),
                       "3 set da 8 a 10, 1 avvicinamento, recupero 2:30")
        XCTAssertEqual(EntrySummary.text(sets: 2, repsMin: 12, repsMax: 15, approaches: 0, fixedRest: nil),
                       "2 set da 12 a 15")
        XCTAssertEqual(EntrySummary.text(sets: 5, repsMin: 5, repsMax: 5, approaches: 0, fixedRest: nil),
                       "5 set da 5")
    }

    func testHints() {
        XCTAssertNil(EntryHints.approach(count: 0))
        XCTAssertEqual(EntryHints.approach(count: 1), "Al 60% del peso di lavoro di oggi.")
        XCTAssertEqual(EntryHints.approach(count: 2), "Al 50% e al 75% del peso di lavoro di oggi.")
        XCTAssertEqual(EntryHints.approach(count: 3), "Al 40%, al 60% e all'80% del peso di lavoro di oggi.")
        XCTAssertEqual(EntryHints.progression(repsMax: 12, step: 2.5),
                       "Quando arrivi a 12 in tutti i set, la volta dopo l'app propone +2,5 kg.")
    }

    func testPlanDaysAndEditorLine() {
        XCTAssertNil(PlanDaysText.list([]))
        XCTAssertEqual(PlanDaysText.list([4, 1]), "Lunedì e giovedì")
        XCTAssertEqual(PlanDaysText.list([6, 1, 3], capitalized: false), "lunedì, mercoledì e sabato")

        let entries = [
            RoutineSummary.Entry(sets: 3, approaches: 2),
            RoutineSummary.Entry(sets: 3, approaches: 1),
            RoutineSummary.Entry(sets: 3, approaches: 1, fixedRest: 150),
            RoutineSummary.Entry(sets: 3),
            RoutineSummary.Entry(sets: 2),
        ]
        let minutes = RoutineSummary.estimatedMinutes(entries)
        XCTAssertEqual(RoutineSummary.editorLine(entries, weekdays: [1, 4]),
                       "5 esercizi, 14 set, circa \(minutes) minuti. Nel piano: lunedì e giovedì")
        XCTAssertEqual(RoutineSummary.editorLine([], weekdays: []), "Nessun esercizio")
        XCTAssertEqual(RoutineSummary.editorLine([RoutineSummary.Entry(sets: 1)], weekdays: [7]),
                       "1 esercizio, 1 set, circa 5 minuti. Nel piano: domenica")
    }

    func testListOrderMatchesSwiftUIMove() {
        let items = ["a", "b", "c", "d"]
        XCTAssertEqual(ListOrder.move(items, from: [0], to: 3), ["b", "c", "a", "d"])
        XCTAssertEqual(ListOrder.move(items, from: [0], to: 4), ["b", "c", "d", "a"])
        XCTAssertEqual(ListOrder.move(items, from: [3], to: 0), ["d", "a", "b", "c"])
        XCTAssertEqual(ListOrder.move(items, from: [1, 2], to: 4), ["a", "d", "b", "c"])
        XCTAssertEqual(ListOrder.move(items, from: [2], to: 2), items)
    }

    func testRoutineNames() {
        XCTAssertEqual(RoutineNames.new(existing: []), "Nuova scheda")
        XCTAssertEqual(RoutineNames.new(existing: ["Nuova scheda", "nuova scheda 2"]), "Nuova scheda 3")
        XCTAssertEqual(RoutineNames.copy(of: "Gambe", existing: ["Gambe"]), "Gambe (copia)")
        XCTAssertEqual(RoutineNames.copy(of: "Gambe", existing: ["Gambe", "Gambe (copia)"]), "Gambe (copia 2)")
    }

    func testCues() {
        XCTAssertEqual(Cues.split("Scapole addotte\n\n  Non staccare la schiena "),
                       ["Scapole addotte", "Non staccare la schiena"])
        XCTAssertEqual(Cues.join([" A ", "", "B"]), "A\nB")
        XCTAssertEqual(Cues.split(""), [])
    }
}

final class UsualRestTests: XCTestCase {
    func testUsualRestFromDurations() {
        XCTAssertNil(SessionStats.usualRest(restDurations: []))
        XCTAssertEqual(SessionStats.usualRest(restDurations: [120, 140]), 130)
        XCTAssertEqual(SessionStats.usualRest(restDurations: [600, 100, 100], lastN: 2), 100)
        XCTAssertEqual(SessionStats.roundedRest(130), 135)
        XCTAssertEqual(SessionStats.roundedRest(2), 15)
        XCTAssertEqual(SessionStats.roundedRest(900), 600)
    }
}
