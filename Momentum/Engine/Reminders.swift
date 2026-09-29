import Foundation

/// One local notification to schedule.
struct Reminder: Equatable {
    let date: Date
    let title: String
    let body: String
}

/// Training-day reminders. Everything happens on the device: the app schedules ordinary local notifications for
/// the next couple of weeks and refreshes them whenever it opens. No server, no push service.
enum Reminders {
    /// iOS keeps at most 64 pending local notifications per app; two weeks of training days is well under that.
    static let daysAhead = 14

    /// The reminders to schedule from `now`. Nothing when the person turned reminders off.
    /// - Parameter minutes: time of day as minutes after midnight (18:30 = 1110).
    static func plan(
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date,
        calendar: Calendar = TrainingCalendar.calendar
    ) -> [Reminder] {
        guard let minutes = profile.reminderMinutes, profile.onboarded else { return [] }
        let clamped = max(0, min(24 * 60 - 1, minutes))
        var reminders: [Reminder] = []
        let today = calendar.startOfDay(for: now)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let time = calendar.date(byAdding: .minute, value: clamped, to: day),
                  time > now,
                  let workout = PlanGenerator.workout(on: day, profile: profile, history: history, now: now) else { continue }
            // Already trained today: no nagging.
            if calendar.isDate(day, inSameDayAs: now),
               history.contains(where: { calendar.isDate($0.date, inSameDayAs: now) }) { continue }
            let name = profile.name.trimmingCharacters(in: .whitespaces)
            let title = name.isEmpty ? L("Time to train") : L("Time to train, {0}", name)
            reminders.append(Reminder(
                date: time,
                title: title,
                body: L("Today: {0}. {1} min.", workout.title, workout.minutes)
            ))
        }
        return reminders
    }
}
