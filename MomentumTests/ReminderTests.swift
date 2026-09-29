import XCTest
@testable import Momentum

final class ReminderTests: EnglishTestCase {
    private func profile(minutes: Int? = 18 * 60 + 30) -> UserProfile {
        var p = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        p.reminderMinutes = minutes
        return p
    }

    func testOffByDefaultAndWhenNotOnboarded() {
        XCTAssertTrue(Reminders.plan(profile: profile(minutes: nil), history: [], now: T.monday).isEmpty)
        var p = profile()
        p.onboarded = false
        XCTAssertTrue(Reminders.plan(profile: p, history: [], now: T.monday).isEmpty)
        XCTAssertNil(UserProfile().reminderMinutes)
    }

    func testOneReminderPerTrainingDayAtTheChosenTime() {
        let now = T.monday                        // Monday 09:00; training days Mon, Wed, Fri
        let reminders = Reminders.plan(profile: profile(), history: [], now: now)
        XCTAssertEqual(reminders.count, 6)        // 3 per week over 14 days
        let calendar = TrainingCalendar.calendar
        for reminder in reminders {
            XCTAssertTrue([2, 4, 6].contains(calendar.component(.weekday, from: reminder.date)))
            XCTAssertEqual(calendar.component(.hour, from: reminder.date), 18)
            XCTAssertEqual(calendar.component(.minute, from: reminder.date), 30)
            XCTAssertGreaterThan(reminder.date, now)
        }
        XCTAssertEqual(reminders.map(\.date), reminders.map(\.date).sorted())
    }

    func testTodayIsSkippedWhenTheTimeHasPassedOrTheWorkoutIsDone() {
        let evening = T.monday.addingTimeInterval(11 * 3600)          // 20:00, after 18:30
        XCTAssertEqual(Reminders.plan(profile: profile(), history: [], now: evening).first.map { TrainingCalendar.calendar.component(.weekday, from: $0.date) }, 4)

        let done = T.session(on: T.monday.addingTimeInterval(3600), logs: [T.log("pushup", sets: [(10, 0)], min: 8, max: 15)])
        let reminders = Reminders.plan(profile: profile(), history: [done], now: T.monday.addingTimeInterval(2 * 3600))
        XCTAssertEqual(TrainingCalendar.calendar.component(.weekday, from: reminders[0].date), 4)   // Wednesday, not today
    }

    func testTextNamesTheWorkoutAndFollowsTheLanguage() {
        var p = profile()
        p.name = "Sam"
        let english = Reminders.plan(profile: p, history: [], now: T.monday)[0]
        XCTAssertEqual(english.title, "Time to train, Sam")
        XCTAssertTrue(english.body.hasPrefix("Today: "), english.body)
        XCTAssertTrue(english.body.hasSuffix(" min."), english.body)

        Loc.language = .es
        defer { Loc.language = .en }
        let spanish = Reminders.plan(profile: p, history: [], now: T.monday)[0]
        XCTAssertNotEqual(spanish.title, english.title)
        XCTAssertFalse(spanish.body.contains("{"))
        XCTAssertTrue(spanish.body.hasPrefix("Hoy: "), spanish.body)
    }

    func testReminderTimeIsClampedAndSurvivesSaving() throws {
        let odd = Reminders.plan(profile: profile(minutes: 99_999), history: [], now: T.monday)
        XCTAssertFalse(odd.isEmpty)
        var p = profile(minutes: 7 * 60)
        p.name = "Sam"
        let decoded = try JSONDecoder().decode(UserProfile.self, from: try JSONEncoder().encode(p))
        XCTAssertEqual(decoded.reminderMinutes, 420)
    }
}
