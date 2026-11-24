import XCTest
@testable import PernoCore

final class BackupTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 18, _ minute: Int = 2,
                      _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute,
                                           second: second))!
    }

    private func sample() -> BackupFile {
        let exercise = UUID()
        let routine = UUID()
        let start = date(2026, 11, 19, 17, 0)
        return BackupFile(
            createdAt: date(2026, 11, 19, 18, 2),
            exercises: [.init(id: exercise, name: "Lat machine", muscleGroup: "back", equipment: "machine",
                              type: "weights", builtInKey: "lat-machine", createdAt: start)],
            routines: [.init(id: routine, name: "Upper body", createdAt: start, entries: [
                .init(position: 0, exerciseID: exercise, setCount: 3, repsMin: 8, repsMax: 12, approachCount: 2,
                      fixedRest: nil, setup: "Sedile 4", cues: "Scapole addotte"),
            ])],
            planDays: [.init(weekday: 4, routineID: routine), .init(weekday: 5, routineID: nil)],
            sessions: [.init(id: UUID(), routineID: routine, routineName: "Upper body", isFree: false,
                             startedAt: start, endedAt: start.addingTimeInterval(3_520),
                             lastActivityAt: start.addingTimeInterval(3_500), closedAutomatically: false,
                             isSaved: true, note: "Bene", exercises: [
                .init(position: 0, exerciseID: exercise, name: "Lat machine", repsMin: 8, repsMax: 12,
                      approachCount: 0, fixedRest: 120, setup: "", cues: "", note: "", isPostponed: false, sets: [
                    .init(position: 0, kind: "work", targetWeight: 55, targetReps: 10, weight: 55, reps: 10,
                          reserve: 1, startedAt: start.addingTimeInterval(400), endedAt: start.addingTimeInterval(430)),
                    .init(position: 1, kind: "work", targetWeight: 55, targetReps: 10, weight: nil, reps: nil,
                          reserve: nil, startedAt: nil, endedAt: nil),
                ]),
            ], pauses: [
                .init(kind: "warmUp", exercisePosition: nil, afterApproach: false, start: start,
                      end: start.addingTimeInterval(300)),
            ])])
    }

    func testRoundTrip() throws {
        let file = sample()
        let decoded = try BackupFile.decode(try file.encoded())
        XCTAssertEqual(decoded, file)
        XCTAssertEqual(BackupText.contents(decoded), "1 sessione, 1 scheda, 1 esercizio")
    }

    func testRejectsNewerVersions() throws {
        var file = sample()
        file.version = BackupFile.currentVersion + 1
        XCTAssertThrowsError(try BackupFile.decode(try file.encoded())) { error in
            XCTAssertEqual(error as? BackupError, .newerVersion)
        }
        XCTAssertThrowsError(try BackupFile.decode(Data("non è json".utf8)))
    }

    func testNamesAndPruning() {
        let name = BackupFiles.name(for: date(2026, 11, 24, 18, 2, 12), calendar: calendar)
        XCTAssertEqual(name, "perno-2026-11-24-180212.json")
        XCTAssertEqual(BackupFiles.date(fromName: name, calendar: calendar), date(2026, 11, 24, 18, 2, 12))
        XCTAssertNil(BackupFiles.date(fromName: "foto.json", calendar: calendar))

        let names = ["perno-2026-11-16-180000.json", "perno-2026-11-24-180212.json", "note.txt",
                     "perno-2026-11-19-190000.json", "perno-2026-11-21-100000.json"]
        XCTAssertEqual(BackupFiles.toDelete(from: names, keep: 3), ["perno-2026-11-16-180000.json"])
        XCTAssertEqual(BackupFiles.toDelete(from: names, keep: 5), [])
        XCTAssertEqual(BackupFiles.toDelete(from: names, keep: 0).count, 3)
        XCTAssertEqual(BackupFiles.backups(in: names).first, "perno-2026-11-24-180212.json")
    }

    func testTexts() {
        let now = date(2026, 11, 24, 20, 0)
        XCTAssertEqual(BackupText.lastBackup(date(2026, 11, 24, 18, 2), now: now, calendar: calendar),
                       "Ultimo backup oggi alle 18:02")
        XCTAssertEqual(BackupText.when(date(2026, 11, 23, 9, 15), now: now, calendar: calendar), "ieri alle 9:15")
        XCTAssertEqual(BackupText.when(date(2026, 11, 19, 18, 2), now: now, calendar: calendar),
                       "il 19 novembre alle 18:02")
        XCTAssertEqual(BackupText.detail(afterSession: "Upper body", copies: 3, oldest: date(2026, 11, 16),
                                         calendar: calendar),
                       "Dopo la sessione Upper body. 3 copie nella cartella, la più vecchia del 16 novembre")
        XCTAssertEqual(BackupText.detail(afterSession: nil, copies: 1, oldest: nil, calendar: calendar),
                       "1 copia nella cartella")
        XCTAssertEqual(BackupText.failure(folder: "Palestra", lastSuccess: date(2026, 11, 19), calendar: calendar),
                       "L'app non può più scrivere nella cartella Palestra, di solito dopo un rinnovo dell'app. "
                       + "L'ultima copia è del 19 novembre; i dati sul telefono sono al sicuro.")
        XCTAssertEqual(BackupText.location(path: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Palestra"),
                       "iCloud Drive")
        XCTAssertEqual(BackupText.location(path: "/private/var/mobile/Containers/Shared/AppGroup/X/File Provider Storage/Palestra"),
                       "Sul mio iPhone")
        XCTAssertEqual(BackupText.settingsSummary(location: "iCloud Drive", folder: "Palestra",
                                                  last: date(2026, 11, 24, 18, 2), failed: false, now: now,
                                                  calendar: calendar),
                       "iCloud Drive, cartella Palestra, ultimo oggi alle 18:02")
        XCTAssertEqual(BackupText.settingsSummary(location: nil, folder: nil, last: nil, failed: false, now: now,
                                                  calendar: calendar),
                       "Nessuna cartella scelta")
    }
}
