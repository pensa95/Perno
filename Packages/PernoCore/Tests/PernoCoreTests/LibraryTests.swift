import XCTest
@testable import PernoCore

final class LibraryTests: XCTestCase {
    private struct Item: Equatable {
        var name: String
        var group: MuscleGroup
    }

    private let items = [
        Item(name: "Pulley basso", group: .back),
        Item(name: "Croci ai cavi", group: .chest),
        Item(name: "Lat machine", group: .back),
        Item(name: "Chest press", group: .chest),
        Item(name: "Alzate laterali", group: .shoulders),
    ]

    private func sections(filter: MuscleGroup? = nil, query: String = "") -> [(MuscleGroup, [String])] {
        LibrarySearch.sections(items, group: \.group, name: \.name, filter: filter, query: query)
            .map { ($0.group, $0.items.map(\.name)) }
    }

    func testSectionsFollowGroupOrderAndSortByName() {
        let result = sections()
        XCTAssertEqual(result.map { $0.0 }, [.chest, .back, .shoulders])
        XCTAssertEqual(result[0].1, ["Chest press", "Croci ai cavi"])
        XCTAssertEqual(result[1].1, ["Lat machine", "Pulley basso"])
    }

    func testFilterByGroup() {
        let result = sections(filter: .back)
        XCTAssertEqual(result.map { $0.0 }, [.back])
        XCTAssertEqual(result[0].1, ["Lat machine", "Pulley basso"])
    }

    func testSearchIgnoresCaseAccentsAndSpaces() {
        XCTAssertTrue(LibrarySearch.matches("Alzate laterali", query: "  LATER "))
        XCTAssertTrue(LibrarySearch.matches("Panca più alta", query: "piu"))
        XCTAssertTrue(LibrarySearch.matches("Chest press", query: ""))
        XCTAssertFalse(LibrarySearch.matches("Chest press", query: "squat"))
        // «la» trova Lat machine e Alzate laterali; le sezioni vuote spariscono.
        XCTAssertEqual(sections(query: "la").map { $0.0 }, [.back, .shoulders])
        XCTAssertTrue(sections(filter: .chest, query: "lat").isEmpty)
    }

    func testSubtitle() {
        XCTAssertEqual(LibrarySearch.subtitle(equipment: .barbell, routines: []), "Bilanciere")
        XCTAssertEqual(LibrarySearch.subtitle(equipment: .machine, routines: ["Upper body"]),
                       "Macchina, in Upper body")
        XCTAssertEqual(LibrarySearch.subtitle(equipment: .cable, routines: ["Upper body", "Gambe", "Upper body"]),
                       "Cavi, in Upper body e Gambe")
        XCTAssertEqual(LibrarySearch.subtitle(equipment: .dumbbell, routines: ["A", "B", "C"]),
                       "Manubri, in A, B e C")
    }

    func testExerciseNameCheck() {
        let existing = ["Leg extension", "Pressa à 45°"]
        XCTAssertEqual(ExerciseName.check("  Hack squat ", existing: existing), .valid("Hack squat"))
        XCTAssertEqual(ExerciseName.check("   ", existing: existing), .empty)
        XCTAssertEqual(ExerciseName.check("leg EXTENSION", existing: existing), .duplicate)
        XCTAssertEqual(ExerciseName.check("pressa a 45°", existing: existing), .duplicate)
    }
}
