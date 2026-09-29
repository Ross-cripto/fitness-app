import XCTest
@testable import Momentum

final class BackupTests: EnglishTestCase {
    private func sampleData() -> PersonalData {
        var profile = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        profile.name = "Sam"
        profile.language = .es
        profile.limitations = [.knees]
        let sessions = [
            T.session(on: T.day(2), logs: [T.log("db_bench", sets: [(10, 20), (9, 20)], min: 8, max: 12)]),
            T.session(on: T.day(0), logs: [T.log("pushup", sets: [(12, 0), (10, 0)], min: 8, max: 15)]),
        ]
        return PersonalData(profile: profile, sessions: sessions, weights: [
            WeightEntry(date: T.day(1), kg: 81.5), WeightEntry(date: T.day(0), kg: 82),
        ])
    }

    func testBackupRoundTripsEverything() throws {
        let original = sampleData()
        let data = try Backup.export(original, now: T.day(5))
        let restored = try Backup.read(data)
        XCTAssertEqual(restored.profile.name, "Sam")
        XCTAssertEqual(restored.profile.language, .es)
        XCTAssertEqual(restored.profile.limitations, [.knees])
        XCTAssertEqual(restored.profile.trainingWeekdays, [2, 4, 6])
        XCTAssertEqual(restored.sessions.count, 2)
        XCTAssertEqual(restored.sessions.map(\.id), original.sessions.sorted { $0.date < $1.date }.map(\.id))
        XCTAssertEqual(restored.sessions.last?.logs.first?.sets, [SetLog(reps: 10, weightKg: 20, seconds: 0), SetLog(reps: 9, weightKg: 20, seconds: 0)])
        XCTAssertEqual(restored.weights.map(\.kg), [82, 81.5])
    }

    func testBackupIsReadableJSONWithAHeader() throws {
        let data = try Backup.export(sampleData(), now: T.day(5))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["format"] as? String, "momentum-backup")
        XCTAssertEqual(json["version"] as? Int, BackupFile.currentVersion)
        XCTAssertNotNil(json["exportedAt"])
    }

    func testRejectsFilesThatAreNotBackups() {
        XCTAssertThrowsError(try Backup.read(Data("hello".utf8))) { XCTAssertEqual($0 as? BackupError, .notABackup) }
        XCTAssertThrowsError(try Backup.read(Data("{}".utf8))) { XCTAssertEqual($0 as? BackupError, .notABackup) }
        XCTAssertThrowsError(try Backup.read(Data(#"{"format":"something-else","version":1}"#.utf8))) {
            XCTAssertEqual($0 as? BackupError, .notABackup)
        }
        // The app's own save file has no header: restoring it by mistake must not silently work.
        let saveFile = try? JSONEncoder().encode(sampleData())
        XCTAssertThrowsError(try Backup.read(saveFile ?? Data())) { XCTAssertEqual($0 as? BackupError, .notABackup) }
    }

    func testNewerBackupsGiveAHelpfulError() {
        let json = #"{"format":"momentum-backup","version":99,"somethingNew":true}"#
        XCTAssertThrowsError(try Backup.read(Data(json.utf8))) { XCTAssertEqual($0 as? BackupError, .newerVersion(99)) }
    }

    func testBrokenBackupsFailWholeInsteadOfPartially() throws {
        var text = String(decoding: try Backup.export(sampleData(), now: T.day(5)), as: UTF8.self)
        text = text.replacingOccurrences(of: "\"sessions\"", with: "\"sessionz\"")
        XCTAssertThrowsError(try Backup.read(Data(text.utf8)))
    }

    func testImpossibleWeightsAreDropped() throws {
        var data = sampleData()
        data.weights.append(WeightEntry(date: T.day(3), kg: -5))
        data.weights.append(WeightEntry(date: T.day(4), kg: 0))
        let restored = try Backup.read(try Backup.export(data))
        XCTAssertEqual(restored.weights.count, 2)
    }

    func testOwnSaveFileStillLoadsAsPersonalData() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(PersonalData.self, from: try encoder.encode(sampleData()))
        XCTAssertEqual(decoded.sessions.count, 2)
    }

    // MARK: CSV

    func testCSVHasOneRowPerSetInDateOrder() {
        let rows = Backup.csv(sessions: sampleData().sessions).split(separator: "\n").map(String.init)
        XCTAssertEqual(rows.first, "date,workout,exercise_id,exercise,set,reps,weight_kg,seconds,effort")
        XCTAssertEqual(rows.count, 1 + 4)
        XCTAssertTrue(rows[1].contains("pushup"), rows[1])          // day 0 comes first
        XCTAssertTrue(rows[3].contains("db_bench") && rows[3].contains(",1,10,20,0,"), rows[3])
    }

    func testCSVEscapesAndDefusesSpreadsheetFormulas() {
        var session = T.session(on: T.day(0), logs: [T.log("pushup", sets: [(10, 0)], min: 8, max: 15)])
        session.title = "=HYPERLINK(\"x\"), \"quoted\""
        let row = Backup.csv(sessions: [session]).split(separator: "\n").map(String.init)[1]
        XCTAssertTrue(row.contains("\"'=HYPERLINK(\"\"x\"\"), \"\"quoted\"\"\""), row)
    }

    func testCSVIsEnglishRegardlessOfAppLanguage() {
        Loc.language = .es
        defer { Loc.language = .en }
        let csv = Backup.csv(sessions: sampleData().sessions)
        XCTAssertTrue(csv.contains("Push-Up") || csv.contains("Push-up"), csv)
    }
}
