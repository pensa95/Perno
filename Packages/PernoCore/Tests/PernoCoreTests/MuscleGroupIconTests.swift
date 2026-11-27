import XCTest
@testable import PernoCore

final class MuscleGroupIconTests: XCTestCase {
    func testEveryGroupHasItsIcon() {
        for group in MuscleGroup.allCases {
            let full = MuscleGroupIcon.highlighted(for: group)
            XCTAssertFalse(full.isEmpty, "\(group)")
            let view = Set(MuscleGroupIcon.zoneNames(view: MuscleGroupIcon.view(for: group)))
            // Le zone piene sono della vista del gruppo e non sono nella sagoma.
            XCTAssertTrue(Set(full).isSubset(of: view), "\(group)")
            XCTAssertTrue(Set(full).isDisjoint(with: MuscleGroupIcon.silhouette(for: group)), "\(group)")
            XCTAssertEqual(Set(full).union(MuscleGroupIcon.silhouette(for: group)), view, "\(group)")
        }
    }

    func testEveryZoneHasAPath() {
        for view in [MuscleGroupIcon.View.front, .back] {
            for name in MuscleGroupIcon.zoneNames(view: view) {
                let path = MuscleGroupIcon.zones[name]
                XCTAssertNotNil(path, name)
                XCTAssertTrue(path?.hasPrefix("M ") == true && path?.hasSuffix("Z") == true, name)
            }
        }
    }

    func testBackIsOnlyForBack() {
        XCTAssertEqual(MuscleGroupIcon.view(for: .back), .back)
        for group in MuscleGroup.allCases where group != .back {
            XCTAssertEqual(MuscleGroupIcon.view(for: group), .front)
        }
    }
}
