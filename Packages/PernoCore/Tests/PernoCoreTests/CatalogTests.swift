import XCTest
@testable import PernoCore

final class CatalogTests: XCTestCase {
    func testStoredRawValuesAreStable() {
        XCTAssertEqual(MuscleGroup.allCases.map(\.rawValue), ["chest", "back", "shoulders", "legs", "arms", "abs"])
        XCTAssertEqual(Equipment.allCases.map(\.rawValue),
                       ["machine", "cable", "barbell", "dumbbell", "bodyweight", "other"])
        XCTAssertEqual(ExerciseType.allCases.map(\.rawValue), ["weights", "bodyweight", "timed"])
        XCTAssertEqual(SetKind.allCases.map(\.rawValue), ["approach", "work", "drop", "failure"])
        XCTAssertEqual(Reserve.allCases.map(\.rawValue), [0, 1, 2, 3, 4])
    }

    func testLabels() {
        XCTAssertEqual(MuscleGroup.allCases.map(\.label), ["Petto", "Schiena", "Spalle", "Gambe", "Braccia", "Addome"])
        XCTAssertEqual(SetKind.allCases.map(\.label), ["Avvicinamento", "Normale", "Drop set", "A cedimento"])
        XCTAssertEqual(Reserve.allCases.map(\.label), ["0", "1", "2", "3", "4+"])
    }

    func testLibraryHasUniqueKeysAndNames() {
        let library = ExerciseLibrary.builtIn
        XCTAssertEqual(Set(library.map(\.key)).count, library.count)
        XCTAssertEqual(Set(library.map { $0.name.lowercased() }).count, library.count)
        XCTAssertTrue(library.allSatisfy { !$0.key.isEmpty && !$0.name.isEmpty })
    }

    func testLibraryCoversEveryGroupWithWeightsOnly() {
        let library = ExerciseLibrary.builtIn
        for group in MuscleGroup.allCases {
            XCTAssertTrue(library.contains { $0.group == group }, "Manca il gruppo \(group.label)")
        }
        // Nella v1 ogni esercizio è a pesi.
        XCTAssertTrue(library.allSatisfy { $0.type == .weights })
    }

    func testWeekdayStartsOnMonday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Rome"))
        func day(_ d: Int) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: 12)))
        }
        XCTAssertEqual(Weekday.of(try day(23), calendar: calendar), 1)   // lunedì
        XCTAssertEqual(Weekday.of(try day(26), calendar: calendar), 4)   // giovedì
        XCTAssertEqual(Weekday.of(try day(29), calendar: calendar), 7)   // domenica
        XCTAssertEqual(Weekday.all, [1, 2, 3, 4, 5, 6, 7])
    }
}
