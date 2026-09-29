import Foundation

/// A believable few weeks of history for screenshots, UI tests and demos. It is produced by the real engine
/// (plan, log what was planned, adapt), so what it shows is what the app would really do.
enum DemoData {
    static func make(language: AppLanguage?, now: Date = Date(), weeks: Int = 6) -> PersonalData {
        var profile = UserProfile()
        profile.name = "Alex"
        profile.language = language
        profile.level = .intermediate
        profile.goal = .buildMuscle
        profile.equipment = .dumbbells
        profile.maxDumbbellKg = 24
        profile.sessionMinutes = 45
        profile.weightKg = 76
        profile.heightCm = 176
        profile.age = 31
        profile.sex = .male
        profile.trainingWeekdays = [2, 4, 6]
        profile.onboarded = true
        let placement = Assessment.place(history: .sixTo24Months, frequency: .threeToFour, check: FitnessCheck())
        profile.rungs = placement.rungs

        let calendar = TrainingCalendar.calendar
        let today = calendar.startOfDay(for: now)
        let firstDay = calendar.date(byAdding: .day, value: -7 * weeks, to: TrainingCalendar.weekStart(of: today)) ?? today
        profile.startDate = firstDay
        profile.blockStart = TrainingCalendar.weekStart(of: firstDay)

        var sessions: [WorkoutSession] = []
        var weights: [WeightEntry] = []
        var day = firstDay
        var previous: Date?
        var index = 0
        while day < today {
            let noon = calendar.date(byAdding: .hour, value: 18, to: day) ?? day
            if let workout = PlanGenerator.workout(on: day, profile: profile, history: sessions, now: noon) {
                index += 1
                // A missed session now and then, like real life.
                if index % 7 != 0 {
                    let session = complete(workout, on: noon, profile: profile, variation: index)
                    sessions.append(session)
                    let outcome = AdaptiveEngine.apply(session: session, to: profile, history: sessions, previousSessionDate: previous)
                    profile = outcome.profile
                    previous = session.date
                }
            }
            if calendar.component(.weekday, from: day) == 2 {
                let step = Double(weights.count)
                weights.append(WeightEntry(date: noon, kg: 78 - step * 0.35))
            }
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? today
        }
        if let last = weights.last { profile.weightKg = last.kg }
        return PersonalData(profile: profile, sessions: sessions, weights: weights)
    }

    /// Logs every planned set at the target, with the odd extra rep so the numbers do not look robotic.
    private static func complete(_ workout: Workout, on date: Date, profile: UserProfile, variation: Int) -> WorkoutSession {
        var logs: [ExerciseLog] = []
        var done = 0
        var planned = 0
        for (offset, item) in workout.exercises.enumerated() {
            let exercise = item.exercise
            let bonus = (variation + offset) % 4 == 0 ? 1 : 0
            var sets: [SetLog] = []
            for setIndex in 0..<item.sets {
                let value = max(1, item.target + (setIndex == 0 ? bonus : 0))
                sets.append(SetLog(
                    reps: exercise.kind == .timed ? 0 : value,
                    weightKg: item.weightKg ?? 0,
                    seconds: exercise.kind == .timed ? value : 0
                ))
            }
            planned += item.sets
            done += sets.count
            logs.append(ExerciseLog(exerciseID: exercise.id, targetSets: item.sets, target: item.target, sets: sets,
                                    repMin: item.repMin, repMax: item.repMax, effort: .good))
        }
        return WorkoutSession(
            date: date, title: workout.title, durationSeconds: workout.minutes * 60,
            calories: workout.calories(weightKg: profile.weightKg), plannedSets: planned, completedSets: done,
            logs: logs, feedback: .justRight, readiness: .normal, wasDeload: workout.phase?.isDeload
        )
    }
}
