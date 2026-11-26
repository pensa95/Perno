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

    func testRingSteps() {
        let tocco = Date(timeIntervalSince1970: 1_000)
        let t0 = Countdown.start(since: tocco)
        func anello(_ dopo: TimeInterval) -> Double { Countdown.ring(at: t0.addingTimeInterval(dopo), since: tocco) }
        // Pieno fino a t0 (anticipo compreso) e fermo fino all'inizio del primo movimento.
        XCTAssertEqual(Countdown.ring(at: tocco, since: tocco), 1)
        XCTAssertEqual(anello(0), 1)
        XCTAssertEqual(anello(0.5), 1)
        // Arriva esattamente sul bip e ci resta fermo.
        XCTAssertEqual(anello(1), 2.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(anello(1.5), 2.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(anello(2), 1.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(anello(2.5), 1.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(anello(3), 0, accuracy: 0.0001)
        XCTAssertEqual(anello(4), 0, accuracy: 0.0001)
        // A metà movimento ha consumato metà del terzo.
        XCTAssertEqual(anello(1 - Countdown.ringMove / 2), 1 - 0.5 / 3, accuracy: 0.0001)
    }

    func testRingNeverIncreases() {
        let tocco = Date(timeIntervalSince1970: 1_000)
        var prima = 1.0
        for passo in 0...400 {
            let valore = Countdown.ring(at: tocco.addingTimeInterval(Double(passo) * 0.01), since: tocco)
            XCTAssertLessThanOrEqual(valore, prima + 1e-9)
            prima = valore
        }
    }
}
