import XCTest
@testable import PernoCore

final class SchemaV3Tests: XCTestCase {
    func testFeelingRawValues() {
        XCTAssertEqual(Feeling.allCases.map(\.rawValue), ["leggero", "giusto", "faticoso"])
        XCTAssertEqual(Feeling.allCases.map(\.title), ["Leggero", "Giusto", "Faticoso"])
        XCTAssertEqual(Feeling(rawValue: "faticoso"), .hard)
        XCTAssertNil(Feeling(rawValue: "boh"))
    }

    func testRoutineLinkMatchesInOrder() {
        let a = UUID(), b = UUID(), c = UUID()
        let v1 = UUID(), v2 = UUID(), v3 = UUID()
        let voci: [(id: UUID, exercise: UUID?)] = [(v1, a), (v2, b), (v3, a)]
        // Sessione: A, esercizio aggiunto C, B, A di nuovo, un esercizio eliminato dalla libreria.
        let legami = RoutineLink.match(session: [a, c, b, a, nil], routine: voci)
        XCTAssertEqual(legami, [v1, nil, v2, v3, nil])
    }

    func testRoutineLinkUsesEachEntryOnce() {
        let a = UUID(), v1 = UUID()
        XCTAssertEqual(RoutineLink.match(session: [a, a], routine: [(v1, a)]), [v1, nil])
        XCTAssertEqual(RoutineLink.match(session: [], routine: [(v1, a)]), [])
    }

    func testBackupReadsOldFilesWithoutNewFields() throws {
        // Backup scritto prima della v6: niente faccine, recupero per esercizio né legami.
        let json = """
        {"version":1,"createdAt":"2026-11-20T10:00:00Z","exercises":[],"planDays":[],
         "routines":[{"id":"\(UUID())","name":"Upper","createdAt":"2026-11-01T10:00:00Z","entries":[
           {"position":0,"setCount":3,"repsMin":8,"repsMax":12,"approachCount":0,"setup":"","cues":""}]}],
         "sessions":[{"id":"\(UUID())","routineName":"Upper","isFree":false,"startedAt":"2026-11-19T17:00:00Z",
           "lastActivityAt":"2026-11-19T18:00:00Z","closedAutomatically":false,"isSaved":true,"note":"",
           "pauses":[],"exercises":[{"position":0,"name":"Chest press","repsMin":8,"repsMax":12,
             "approachCount":0,"setup":"","cues":"","note":"","isPostponed":false,"sets":[
               {"position":0,"kind":"work","targetWeight":60,"targetReps":10,"weight":60,"reps":10,"reserve":1}]}]}]}
        """
        let file = try BackupFile.decode(Data(json.utf8))
        let voce = try XCTUnwrap(file.routines.first?.entries.first)
        XCTAssertNil(voce.id)
        XCTAssertNil(voce.restMode)
        XCTAssertNil(voce.autoStartAfterRest)
        let esercizio = try XCTUnwrap(file.sessions.first?.exercises.first)
        XCTAssertNil(esercizio.routineEntryID)
        XCTAssertNil(esercizio.addedFromRoutine)
        XCTAssertNil(esercizio.restMode)
        let set = try XCTUnwrap(esercizio.sets.first)
        XCTAssertNil(set.feeling)
        XCTAssertEqual(set.reserve, 1)
    }

    func testBackupRoundTripKeepsNewFields() throws {
        let voceID = UUID()
        let file = BackupFile(
            createdAt: Date(timeIntervalSince1970: 1_800_000_000), exercises: [],
            routines: [.init(id: UUID(), name: "Upper", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                             entries: [.init(position: 0, exerciseID: nil, setCount: 3, repsMin: 8, repsMax: 12,
                                             approachCount: 0, fixedRest: nil, setup: "", cues: "",
                                             id: voceID, restMode: RestMode.countdown.rawValue,
                                             autoStartAfterRest: true)])],
            planDays: [],
            sessions: [.init(id: UUID(), routineID: nil, routineName: "Upper", isFree: false,
                             startedAt: Date(timeIntervalSince1970: 1_799_000_000), endedAt: nil,
                             lastActivityAt: Date(timeIntervalSince1970: 1_799_000_100),
                             closedAutomatically: false, isSaved: false, note: "",
                             exercises: [.init(position: 0, exerciseID: nil, name: "Chest press", repsMin: 8,
                                               repsMax: 12, approachCount: 0, fixedRest: nil, setup: "", cues: "",
                                               note: "", isPostponed: false,
                                               sets: [.init(position: 0, kind: "work", targetWeight: 60,
                                                            targetReps: 10, weight: 60, reps: 11, reserve: nil,
                                                            startedAt: nil, endedAt: nil,
                                                            feeling: Feeling.light.rawValue)],
                                               routineEntryID: voceID, addedFromRoutine: true,
                                               restMode: RestMode.stopwatch.rawValue, autoStartAfterRest: false)],
                             pauses: [])])
        let letto = try BackupFile.decode(file.encoded())
        XCTAssertEqual(letto, file)
        XCTAssertEqual(letto.sessions.first?.exercises.first?.sets.first?.feeling, "leggero")
        XCTAssertEqual(letto.routines.first?.entries.first?.restMode, "countdown")
    }
}
