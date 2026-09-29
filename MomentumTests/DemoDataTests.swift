import XCTest
@testable import Momentum

final class DemoDataTests: EnglishTestCase {
    func testDemoHistoryLooksLikeSixWeeksOfTraining() {
        let now = T.week(8)
        let data = DemoData.make(language: .es, now: now)
        XCTAssertEqual(data.profile.language, .es)
        XCTAssertTrue(data.profile.onboarded)
        XCTAssertTrue((12...18).contains(data.sessions.count), "\(data.sessions.count)")
        XCTAssertTrue(data.sessions.allSatisfy { $0.date < now && !$0.logs.isEmpty && $0.completedSets > 0 })
        XCTAssertEqual(data.sessions.map(\.date), data.sessions.map(\.date).sorted())
        XCTAssertEqual(data.weights.count, 6)
        XCTAssertGreaterThan(data.weights.first!.kg, data.weights.last!.kg)
    }

    func testDemoIsDeterministic() {
        let a = DemoData.make(language: nil, now: T.week(8))
        let b = DemoData.make(language: nil, now: T.week(8))
        XCTAssertEqual(a.sessions.map(\.title), b.sessions.map(\.title))
        XCTAssertEqual(a.sessions.map { $0.logs.map(\.exerciseID) }, b.sessions.map { $0.logs.map(\.exerciseID) })
    }

    func testDemoShowsRealProgression() {
        let data = DemoData.make(language: nil, now: T.week(8))
        // Some lift went up over the weeks, because the engine progresses what was logged.
        var firstAndLast: [String: (Double, Double)] = [:]
        for session in data.sessions {
            for log in session.logs {
                let load = log.sets.map(\.weightKg).max() ?? 0
                guard load > 0 else { continue }
                firstAndLast[log.exerciseID] = (firstAndLast[log.exerciseID]?.0 ?? load, load)
            }
        }
        XCTAssertTrue(firstAndLast.values.contains { $0.1 > $0.0 }, "\(firstAndLast)")
    }

    func testDemoSurvivesABackupRoundTrip() throws {
        let data = DemoData.make(language: .pt, now: T.week(8))
        let restored = try Backup.read(try Backup.export(data))
        XCTAssertEqual(restored.sessions.count, data.sessions.count)
        XCTAssertEqual(restored.profile.language, .pt)
    }
}
