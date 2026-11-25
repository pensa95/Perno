import XCTest
@testable import PernoCore

final class MeasureTests: XCTestCase {
    func testRawValuesAndLabels() {
        XCTAssertEqual(SetMeasure.allCases.map(\.rawValue), ["reps", "time"])
        XCTAssertEqual(SetMeasure.allCases.map(\.label), ["Ripetizioni", "Tempo"])
        XCTAssertEqual(SetMeasure(rawValue: "time"), .time)
    }

    func testDurationSteps() {
        XCTAssertEqual(DurationLimits.stepped(45, by: 1), 50)
        XCTAssertEqual(DurationLimits.stepped(45, by: -1), 40)
        XCTAssertEqual(DurationLimits.stepped(5, by: -1), 5)
        XCTAssertEqual(DurationLimits.stepped(600, by: 1), 600)
        XCTAssertEqual(DurationLimits.stepped(43, by: 1), 50)
        XCTAssertEqual(DurationLimits.clamp(0), 5)
    }

    func testTimedSummary() {
        XCTAssertEqual(EntrySummary.timed(sets: 3, seconds: 45, withWeight: false, fixedRest: nil), "3 set da 0:45")
        XCTAssertEqual(EntrySummary.timed(sets: 3, seconds: 45, withWeight: true, fixedRest: nil),
                       "3 set da 0:45, con peso")
        XCTAssertEqual(EntrySummary.timed(sets: 2, seconds: 90, withWeight: true, fixedRest: 120),
                       "2 set da 1:30, con peso, recupero 2:00")
    }

    func testSummaryByMeasure() {
        XCTAssertEqual(EntrySummary.text(measure: .reps, sets: 3, repsMin: 8, repsMax: 12, approaches: 2,
                                         seconds: 45, withWeight: true, fixedRest: nil),
                       "3 set da 8 a 12, 2 avvicinamenti")
        XCTAssertEqual(EntrySummary.text(measure: .time, sets: 3, repsMin: 8, repsMax: 12, approaches: 2,
                                         seconds: 45, withWeight: false, fixedRest: nil),
                       "3 set da 0:45")
    }

    func testTimedProgressionHint() {
        XCTAssertEqual(EntryHints.timedProgression(seconds: 45),
                       "Quando tieni 0:45 in tutti i set, la volta dopo l'app propone +5 s.")
    }

    func testBackupReadsOldEntriesWithoutMeasure() throws {
        let json = """
        {"position":0,"setCount":3,"repsMin":8,"repsMax":12,"approachCount":0,"setup":"","cues":""}
        """
        let entry = try JSONDecoder().decode(BackupFile.Entry.self, from: Data(json.utf8))
        XCTAssertNil(entry.measure)
        XCTAssertNil(entry.targetSeconds)
        XCTAssertNil(entry.withWeight)
    }

    func testBackupKeepsTimedFields() throws {
        let entry = BackupFile.Entry(position: 0, exerciseID: nil, setCount: 3, repsMin: 8, repsMax: 12,
                                     approachCount: 0, fixedRest: nil, setup: "", cues: "",
                                     measure: "time", targetSeconds: 45, withWeight: true)
        let data = try JSONEncoder().encode(entry)
        XCTAssertEqual(try JSONDecoder().decode(BackupFile.Entry.self, from: data), entry)
    }
}
