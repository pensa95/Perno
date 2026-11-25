import XCTest
@testable import PernoCore

final class TimedHistoryTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }()

    override func setUp() {
        Units.unit = .kilograms
        Units.step = PlateStep.standard
    }

    private func day(_ d: Int, _ m: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: 18))!
    }

    /// Set a tempo come `Lift`: le ripetizioni sono i secondi.
    private func plank(_ entries: [(Date, [(Double, Int)])]) -> ExerciseHistory.Exercise<Int> {
        ExerciseHistory.Exercise(id: 1, name: "Plank", entries: entries.map { date, sets in
            ExerciseHistory.Entry(date: date, lifts: sets.map { SessionSummary.Lift(weight: $0.0, reps: $0.1) })
        }, timed: true)
    }

    func testTimedWithoutWeightIsValid() {
        let exercise = plank([(day(9, 11), [(0, 40), (0, 45)])])
        XCTAssertEqual(exercise.record?.lift.reps, 45)
        XCTAssertEqual(exercise.text(exercise.record!.lift), "0:45")
        // Lo stesso set a ripetizioni con peso 0 non vale.
        let reps = ExerciseHistory.Exercise(id: 1, name: "Plank", entries: exercise.entries)
        XCTAssertNil(reps.record)
    }

    func testRecordIsLongestDuration() {
        let exercise = plank([(day(2, 11), [(20, 40)]), (day(9, 11), [(10, 55), (10, 50)]), (day(16, 11), [(10, 50)])])
        XCTAssertEqual(exercise.record?.lift, SessionSummary.Lift(weight: 10, reps: 55))
        XCTAssertEqual(exercise.record?.date, day(9, 11))
        XCTAssertEqual(exercise.text(exercise.record!.lift), "10 × 0:55")
        XCTAssertEqual(exercise.last?.lift.reps, 50)
        XCTAssertEqual(ExerciseDetail.recordDates(exercise), [day(9, 11)])
        XCTAssertEqual(ExerciseDetail.points(exercise).map(\.estimatedMax), [40, 55, 50])
    }

    func testTexts() {
        let points = [ExerciseDetail.Point(date: day(1, 6), estimatedMax: 35),
                      ExerciseDetail.Point(date: day(1, 11), estimatedMax: 55)]
        XCTAssertEqual(ExerciseDetail.timedChange(points, range: .sixMonths), "+20 s in 6 mesi")
        XCTAssertNil(ExerciseDetail.timedChange([points[0]], range: .sixMonths))
        XCTAssertEqual(ExerciseDetail.timedRecordDetail(date: day(12, 11), calendar: calendar),
                       "giovedì 12 novembre · durata più lunga")
        XCTAssertEqual(ExerciseHistory.lastText("10 × 0:45", date: day(19, 11), today: day(25, 11), calendar: calendar),
                       "Ultima: 10 × 0:45, gio 19")
    }
}
