import Foundation

/// A short look back at a week and a heads-up about the next one. Every line is derived from the same rules the
/// plan uses, so the review never promises something the engine will not do.
struct WeeklyReview {
    let weekStart: Date
    /// Workouts scheduled in the week, and how many were finished.
    let plannedSessions: Int
    let completedSessions: Int
    /// Exercises where this week's best beat everything before it.
    let records: [Exercise]
    /// What changes next week (a deload, a fresh block), if anything.
    let nextWeek: String?

    static func make(
        profile: UserProfile,
        sessions: [WorkoutSession],
        weekContaining date: Date,
        now: Date = Date(),
        calendar: Calendar = TrainingCalendar.calendar
    ) -> WeeklyReview {
        let start = TrainingCalendar.weekStart(of: date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let inWeek = sessions.filter { $0.date >= start && $0.date < end }

        let planned = (0..<7).filter { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return false }
            return PlanGenerator.isTrainingDay(day, profile: profile)
        }.count

        // Records: the week's best beats every earlier session (and there is something earlier to beat).
        var records: [Exercise] = []
        for id in Set(inWeek.flatMap { $0.logs.map(\.exerciseID) }).sorted() {
            guard let exercise = ExerciseLibrary.byID[id] else { continue }
            let points = ExerciseProgress.series(exerciseID: id, sessions: sessions)
            let before = points.filter { $0.date < start }.map(\.value).max()
            let during = points.filter { $0.date >= start && $0.date < end }.map(\.value).max()
            if let before, let during, during > before { records.append(exercise) }
        }

        let next = Periodization.phase(on: end, profile: profile, history: sessions, now: now)
        var note: String?
        if next.isDeload {
            note = L("Next week is a lighter deload week, so you come back stronger.")
        } else if next.weekInBlock == 0 && end > now {
            note = L("Next week starts a new training block.")
        }

        return WeeklyReview(weekStart: start, plannedSessions: planned, completedSessions: inWeek.count, records: records, nextWeek: note)
    }
}
