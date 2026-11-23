import XCTest
@testable import PernoCore

final class RestTimerTests: XCTestCase {
    func testDuration() {
        XCTAssertEqual(RestTimer.duration(fixed: 90, usual: 130), 90)
        XCTAssertEqual(RestTimer.duration(fixed: nil, usual: 131.4), 130)
        XCTAssertEqual(RestTimer.duration(fixed: nil, usual: 133), 135)
        XCTAssertEqual(RestTimer.duration(fixed: nil, usual: nil), 120)
        XCTAssertEqual(RestTimer.duration(fixed: nil, usual: 1), 5)
    }

    func testDisplay() {
        XCTAssertEqual(RestTimer.display(mode: .stopwatch, elapsed: 102.6, duration: 120), "1:42")
        XCTAssertEqual(RestTimer.display(mode: .countdown, elapsed: 0, duration: 120), "2:00")
        XCTAssertEqual(RestTimer.display(mode: .countdown, elapsed: 91.5, duration: 120), "0:29")
        XCTAssertEqual(RestTimer.display(mode: .countdown, elapsed: 120, duration: 120), "+0:00")
        XCTAssertEqual(RestTimer.display(mode: .countdown, elapsed: 132.4, duration: 120), "+0:12")
    }

    func testLabelAndToggle() {
        XCTAssertEqual(RestTimer.label(fixed: 120, usual: 130), "Recupero, fissato a 2:00")
        XCTAssertEqual(RestTimer.label(fixed: nil, usual: 130), "Recupero, di solito 2:10")
        XCTAssertEqual(RestTimer.label(fixed: nil, usual: nil), "Recupero")
        XCTAssertEqual(RestMode.stopwatch.toggled, .countdown)
        XCTAssertEqual(RestMode.countdown.toggled, .stopwatch)
    }
}
