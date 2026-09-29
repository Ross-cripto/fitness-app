import XCTest
@testable import Momentum

final class HistoryTests: EnglishTestCase {
    func testSetLinesReadNaturally() {
        let bench = ExerciseLibrary.exercise("db_bench")
        let pushup = ExerciseLibrary.exercise("pushup")
        let plank = ExerciseLibrary.exercise("plank")
        XCTAssertEqual(SessionSummary.line(for: SetLog(reps: 10, weightKg: 20, seconds: 0), exercise: bench, units: .metric), "10 × 20 kg")
        XCTAssertEqual(SessionSummary.line(for: SetLog(reps: 10, weightKg: 20, seconds: 0), exercise: bench, units: .imperial), "10 × 44 lb")
        XCTAssertEqual(SessionSummary.line(for: SetLog(reps: 12, weightKg: 0, seconds: 0), exercise: pushup, units: .metric), "12 reps")
        XCTAssertEqual(SessionSummary.line(for: SetLog(reps: 1, weightKg: 0, seconds: 0), exercise: pushup, units: .metric), "1 rep")
        XCTAssertEqual(SessionSummary.line(for: SetLog(reps: 0, weightKg: 0, seconds: 45), exercise: plank, units: .metric), "45 sec")
        // A loaded lift logged with no weight (bodyweight day) reads as plain reps.
        XCTAssertEqual(SessionSummary.line(for: SetLog(reps: 8, weightKg: 0, seconds: 0), exercise: bench, units: .metric), "8 reps")
    }

    func testLogSummaryJoinsSets() {
        let log = T.log("db_bench", sets: [(10, 20), (9, 20), (8, 20)], min: 8, max: 12)
        XCTAssertEqual(SessionSummary.summary(of: log, units: .metric), "10 × 20 kg · 9 × 20 kg · 8 × 20 kg")
    }

    func testUnknownExercisesDoNotCrashTheHistory() {
        let log = ExerciseLog(exerciseID: "removed_in_v2", targetSets: 3, target: 10, sets: [SetLog(reps: 10, weightKg: 0, seconds: 0)])
        XCTAssertEqual(SessionSummary.summary(of: log, units: .metric), "")
    }

    func testMonthsAreNewestFirstAndSessionsToo() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
        let sessions = [
            T.session(on: day(2026, 1, 3), logs: []), T.session(on: day(2026, 3, 1), logs: []),
            T.session(on: day(2026, 1, 20), logs: []), T.session(on: day(2025, 12, 31), logs: []),
        ]
        let months = SessionSummary.months(sessions, calendar: calendar)
        XCTAssertEqual(months.count, 3)
        XCTAssertEqual(months.map { calendar.component(.month, from: $0.start) }, [3, 1, 12])
        XCTAssertEqual(months[1].sessions.map { calendar.component(.day, from: $0.date) }, [20, 3])
    }

    func testNoSessionsNoMonths() {
        XCTAssertTrue(SessionSummary.months([]).isEmpty)
    }
}
