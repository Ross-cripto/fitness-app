import XCTest
@testable import Momentum

enum T {
    /// Monday, 5 January 2026, 09:00.
    static var monday: Date { day(0) }

    static func day(_ offset: Int) -> Date {
        var c = Calendar.current
        c.firstWeekday = 2
        let base = c.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9))!
        return c.date(byAdding: .day, value: offset, to: base)!
    }

    static func week(_ n: Int) -> Date { day(7 * n) }

    static func profile(
        level: FitnessLevel = .intermediate,
        goal: Goal = .buildMuscle,
        equipment: Equipment = .dumbbells,
        weekdays: [Int] = [2, 4, 6],
        minutes: Int = 45,
        limitations: [BodyArea] = [],
        lowImpact: Bool = false,
        maxDumbbell: Double = 0,
        sex: Sex = .male,
        age: Int = 30,
        weight: Double = 80
    ) -> UserProfile {
        var p = UserProfile()
        p.level = level
        p.goal = goal
        p.equipment = equipment
        p.trainingWeekdays = weekdays
        p.sessionMinutes = minutes
        p.limitations = limitations
        p.lowImpactOnly = lowImpact
        p.maxDumbbellKg = maxDumbbell
        p.sex = sex
        p.age = age
        p.weightKg = weight
        p.startDate = monday
        p.blockStart = monday
        p.onboarded = true
        let placement = Assessment.place(history: level == .beginner ? .never : (level == .intermediate ? .sixTo24Months : .over2Years),
                                         frequency: level == .beginner ? .none : (level == .intermediate ? .threeToFour : .fivePlus),
                                         check: FitnessCheck())
        p.rungs = placement.rungs
        return p
    }

    static func log(
        _ id: String, sets: [(reps: Int, kg: Double)], target: Int? = nil, targetSets: Int? = nil,
        min: Int, max: Int, effort: Effort? = nil, seconds: Bool = false
    ) -> ExerciseLog {
        ExerciseLog(
            exerciseID: id,
            targetSets: targetSets ?? sets.count,
            target: target ?? min,
            sets: sets.map { SetLog(reps: seconds ? 0 : $0.reps, weightKg: $0.kg, seconds: seconds ? $0.reps : 0) },
            repMin: min, repMax: max, effort: effort
        )
    }

    static func session(
        on date: Date, logs: [ExerciseLog], feedback: WorkoutFeedback? = .justRight,
        planned: Int? = nil, done: Int? = nil
    ) -> WorkoutSession {
        let total = logs.reduce(0) { $0 + $1.sets.count }
        return WorkoutSession(
            date: date, title: "t", durationSeconds: 2400, calories: 200,
            plannedSets: planned ?? total, completedSets: done ?? total, logs: logs, feedback: feedback
        )
    }

    /// A finished, unremarkable session (all planned sets done, felt right).
    static func okSession(on date: Date) -> WorkoutSession {
        session(on: date, logs: [], feedback: .justRight, planned: 10, done: 10)
    }

    static func range(_ id: String, _ p: UserProfile) -> RepRange {
        Progression.repRange(for: ExerciseLibrary.exercise(id), goal: p.goal, level: p.level)
    }
}
