import XCTest
@testable import PernoCore

final class PendingDeletionTests: XCTestCase {
    func testHideUndoAndFinish() {
        let a = UUID(), b = UUID()
        var pending = PendingDeletions()
        XCTAssertTrue(pending.isEmpty)
        pending.hide(a)
        pending.hide(b)
        XCTAssertTrue(pending.isHidden(a))
        XCTAssertTrue(pending.undo(a))
        XCTAssertFalse(pending.isHidden(a))
        XCTAssertFalse(pending.undo(a), "già annullata")
        pending.finish(b)
        XCTAssertTrue(pending.isEmpty)
    }

    func testVisibleSkipsHidden() {
        let a = UUID(), b = UUID(), c = UUID()
        var pending = PendingDeletions()
        XCTAssertEqual(pending.visible([a, b, c], id: { $0 }), [a, b, c])
        pending.hide(b)
        XCTAssertEqual(pending.visible([a, b, c], id: { $0 }), [a, c])
    }

    func testStoredRoundTrip() {
        let a = UUID(), b = UUID()
        var pending = PendingDeletions()
        pending.hide(a)
        pending.hide(b)
        let again = PendingDeletions(stored: pending.stored + ["non-un-uuid"])
        XCTAssertEqual(again, pending)
    }

    func testTexts() {
        XCTAssertEqual(PendingDeletions.undoDuration, 5)
        XCTAssertEqual(PendingDeletions.sessionDeletedTitle, "Sessione eliminata")
    }
}
