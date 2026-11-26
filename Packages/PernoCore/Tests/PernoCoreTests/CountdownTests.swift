import XCTest
@testable import PernoCore

final class CountdownTests: XCTestCase {
    private let tocco = Date(timeIntervalSince1970: 1_000)

    func testAlwaysThreeSeconds() {
        XCTAssertEqual(Countdown.seconds, 3)
        XCTAssertEqual(Countdown.end(since: tocco).timeIntervalSince(Countdown.start(since: tocco)), 3)
    }

    func testBeepsFallOnNumberChanges() {
        let bip = Countdown.beeps(since: tocco)
        XCTAssertEqual(bip.count, 3)
        XCTAssertEqual(bip.first, Countdown.start(since: tocco))
        // Ogni bip cade nell'istante in cui compare il suo numero: 3, 2, 1.
        for (indice, istante) in bip.enumerated() {
            XCTAssertEqual(Countdown.value(at: istante, since: tocco), 3 - indice)
            XCTAssertEqual(Countdown.value(at: istante.addingTimeInterval(0.99), since: tocco), 3 - indice)
            XCTAssertEqual(Countdown.remaining(at: istante, since: tocco), 1 - Double(indice) / 3, accuracy: 0.0001)
        }
        // Un secondo per uno, poi il «via».
        XCTAssertEqual(bip[1].timeIntervalSince(bip[0]), 1)
        XCTAssertEqual(bip[2].timeIntervalSince(bip[1]), 1)
        XCTAssertEqual(Countdown.end(since: tocco).timeIntervalSince(bip[2]), 1)
        XCTAssertEqual(Countdown.remaining(at: Countdown.end(since: tocco), since: tocco), 0)
    }

    func testLeadShowsFullThree() {
        XCTAssertEqual(Countdown.value(at: tocco, since: tocco), 3)
        XCTAssertEqual(Countdown.remaining(at: tocco, since: tocco), 1)
        XCTAssertGreaterThan(Countdown.lead, 0)
        XCTAssertLessThan(Countdown.lead, 0.5)
    }

    func testRestEndsAtTapNotAtStart() throws {
        var session = SessionMachine(exercises: [
            PlannedExercise(name: "A", sets: [PlannedSet(kind: .work, weight: 50, reps: 10),
                                              PlannedSet(kind: .work, weight: 50, reps: 10)]),
        ], warmUp: false, at: tocco)
        let inizia = tocco.addingTimeInterval(30)
        try session.start(at: inizia)
        try session.countdownFinished(at: Countdown.end(since: inizia))
        XCTAssertEqual(session.pauses.last?.end, inizia)
        XCTAssertEqual(session.phase, .inSet(since: Countdown.end(since: inizia)))
    }
}
