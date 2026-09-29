import XCTest
@testable import Momentum

final class WeeklyReviewTests: EnglishTestCase {
    private func profile() -> UserProfile { T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6]) }
    private func bench(_ kg: Double, on day: Date) -> WorkoutSession {
        T.session(on: day, logs: [T.log("db_bench", sets: [(10, kg)], min: 8, max: 12)])
    }

    func testCountsPlannedAndCompletedSessions() {
        let history = [bench(20, on: T.day(0)), bench(20, on: T.day(2))]
        let review = WeeklyReview.make(profile: profile(), sessions: history, weekContaining: T.day(3), now: T.day(3))
        XCTAssertEqual(review.plannedSessions, 3)
        XCTAssertEqual(review.completedSessions, 2)
        XCTAssertEqual(review.weekStart, TrainingCalendar.calendar.startOfDay(for: T.monday))
    }

    func testRecordsNeedSomethingEarlierToBeat() {
        let firstEver = WeeklyReview.make(profile: profile(), sessions: [bench(20, on: T.day(0))], weekContaining: T.day(0), now: T.day(1))
        XCTAssertTrue(firstEver.records.isEmpty)

        let history = [bench(20, on: T.day(-7)), bench(22.5, on: T.day(0))]
        let better = WeeklyReview.make(profile: profile(), sessions: history, weekContaining: T.day(0), now: T.day(1))
        XCTAssertEqual(better.records.map(\.id), ["db_bench"])

        let worse = WeeklyReview.make(profile: profile(), sessions: [bench(25, on: T.day(-7)), bench(22.5, on: T.day(0))], weekContaining: T.day(0), now: T.day(1))
        XCTAssertTrue(worse.records.isEmpty)
    }

    func testWarnsAboutTheDeloadWeekBeforeItStarts() {
        let p = profile()
        let length = Periodization.blockLength(for: .intermediate)
        let review = WeeklyReview.make(profile: p, sessions: [], weekContaining: T.week(length - 2), now: T.week(length - 2))
        XCTAssertEqual(review.nextWeek, "Next week is a lighter deload week, so you come back stronger.")
        let quiet = WeeklyReview.make(profile: p, sessions: [], weekContaining: T.week(1), now: T.week(1))
        XCTAssertNil(quiet.nextWeek)
    }

    func testAnnouncesANewBlock() {
        let p = profile()
        let length = Periodization.blockLength(for: .intermediate)
        let review = WeeklyReview.make(profile: p, sessions: [], weekContaining: T.week(length - 1), now: T.week(length - 1))
        XCTAssertEqual(review.nextWeek, "Next week starts a new training block.")
    }

    func testTextIsTranslated() {
        Loc.language = .pt
        defer { Loc.language = .en }
        let length = Periodization.blockLength(for: .intermediate)
        let review = WeeklyReview.make(profile: profile(), sessions: [], weekContaining: T.week(length - 2), now: T.week(length - 2))
        XCTAssertNotNil(review.nextWeek)
        XCTAssertFalse(review.nextWeek!.hasPrefix("Next week"))
    }
}
