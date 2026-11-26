import XCTest
@testable import PernoCore

final class PlateTextTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 10_000)

    private func fatto(_ esercizio: Int, _ set: Int, fine: TimeInterval) -> CompletedSet {
        CompletedSet(exerciseIndex: esercizio, setIndex: set, kind: .work, weight: 60, reps: 10,
                     startedAt: t0.addingTimeInterval(fine - 30), endedAt: t0.addingTimeInterval(fine))
    }

    private func recupero(_ esercizio: Int, da: TimeInterval, a: TimeInterval) -> Pause {
        Pause(kind: .rest, exerciseIndex: esercizio, afterApproach: false,
              start: t0.addingTimeInterval(da), end: t0.addingTimeInterval(a))
    }

    func testMeasuredRestsFollowEachDoneSet() {
        let completati = [fatto(0, 0, fine: 0), fatto(0, 1, fine: 200), fatto(1, 0, fine: 500)]
        let pause = [recupero(0, da: 0, a: 132),
                     Pause(kind: .changeover, exerciseIndex: 1, afterApproach: false,
                           start: t0.addingTimeInterval(200), end: t0.addingTimeInterval(300)),
                     recupero(1, da: 500, a: 560)]
        let riposi = PlateText.measuredRests(exercise: 0, setCount: 3, completed: completati, pauses: pause)
        // Dopo il set 1: 2:12; dopo il set 2 (ultimo dell'esercizio) nessun recupero; set 3 non fatto.
        XCTAssertEqual(riposi, [132, nil, nil])
        XCTAssertEqual(PlateText.measuredRests(exercise: 1, setCount: 1, completed: completati, pauses: pause), [60])
        XCTAssertEqual(PlateText.measuredRests(exercise: 0, setCount: 0, completed: completati, pauses: pause), [])
    }

    func testTexts() {
        XCTAssertEqual(PlateText.restDone(132), "recupero 2:12")
        XCTAssertEqual(PlateText.restDone(65.4), "recupero 1:05")
        XCTAssertEqual(PlateText.restNote(fixed: 120, usual: 130), "fissato a 2:00")
        XCTAssertEqual(PlateText.restNote(fixed: nil, usual: 130), "di solito 2:10")
        XCTAssertNil(PlateText.restNote(fixed: nil, usual: nil))
        XCTAssertEqual(PlateText.overTarget(done: 13, target: 10), "+3")
        XCTAssertNil(PlateText.overTarget(done: 10, target: 10))
        XCTAssertNil(PlateText.overTarget(done: 9, target: 10))
    }
}
