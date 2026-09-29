import Foundation

/// Which muscles a training day hits, in priority order (big lifts first).
enum DayFocus: String, CaseIterable {
    case fullBodyA, fullBodyB, fullBodyC, upper, lower, push, pull, legs

    var title: String {
        switch self {
        case .fullBodyA, .fullBodyB, .fullBodyC: return "Full Body"
        case .upper: return "Upper Body"
        case .lower: return "Lower Body"
        case .push: return "Push Day"
        case .pull: return "Pull Day"
        case .legs: return "Leg Day"
        }
    }

    var subtitle: String {
        switch self {
        case .fullBodyA: return "Squat & press emphasis"
        case .fullBodyB: return "Pull & hinge emphasis"
        case .fullBodyC: return "Total-body conditioning"
        case .upper: return "Chest, back, shoulders, arms"
        case .lower: return "Quads, glutes, hamstrings"
        case .push: return "Chest, shoulders, triceps"
        case .pull: return "Back and biceps"
        case .legs: return "Legs and core"
        }
    }

    var theme: MuscleGroup {
        switch self {
        case .fullBodyA, .fullBodyB, .fullBodyC: return .fullBody
        case .upper, .push: return .chest
        case .pull: return .back
        case .lower, .legs: return .legs
        }
    }

    var slots: [MuscleGroup] {
        switch self {
        case .fullBodyA: return [.legs, .chest, .back, .shoulders, .core, .arms, .legs, .cardio]
        case .fullBodyB: return [.legs, .back, .chest, .core, .shoulders, .arms, .legs, .cardio]
        case .fullBodyC: return [.fullBody, .legs, .chest, .back, .core, .arms, .shoulders, .cardio]
        case .upper: return [.chest, .back, .shoulders, .back, .chest, .arms, .arms, .core]
        case .lower: return [.legs, .legs, .legs, .legs, .core, .core, .cardio, .legs]
        case .push: return [.chest, .shoulders, .chest, .arms, .shoulders, .core, .chest, .arms]
        case .pull: return [.back, .back, .arms, .back, .core, .arms, .shoulders, .core]
        case .legs: return [.legs, .legs, .legs, .legs, .legs, .core, .cardio, .legs]
        }
    }
}

enum QuickKind: String, CaseIterable, Identifiable {
    case short, noEquipment, mobility

    var id: String { rawValue }
}

enum PlanGenerator {
    // MARK: Schedule

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // weeks start on Monday
        return calendar
    }

    static func clampedDays(_ days: Int) -> Int { max(1, min(6, days)) }

    /// Calendar weekdays (1 = Sunday ... 7 = Saturday) used for training, spread for recovery.
    static func weekdays(forDays days: Int) -> [Int] {
        switch clampedDays(days) {
        case 1: return [2]
        case 2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 6, 7]
        default: return [2, 3, 4, 5, 6, 7]
        }
    }

    static func split(for profile: UserProfile) -> [DayFocus] {
        switch clampedDays(profile.daysPerWeek) {
        case 1: return [.fullBodyA]
        case 2: return [.fullBodyA, .fullBodyB]
        case 3: return profile.level == .advanced ? [.push, .pull, .legs] : [.fullBodyA, .fullBodyB, .fullBodyC]
        case 4: return [.upper, .lower, .upper, .lower]
        case 5: return [.push, .pull, .legs, .upper, .lower]
        default: return [.push, .pull, .legs, .push, .pull, .legs]
        }
    }

    static func slot(on date: Date, profile: UserProfile) -> (focus: DayFocus, index: Int)? {
        let weekday = calendar.component(.weekday, from: date)
        guard let index = weekdays(forDays: profile.daysPerWeek).firstIndex(of: weekday) else { return nil }
        return (split(for: profile)[index], index)
    }

    static func isTrainingDay(_ date: Date, profile: UserProfile) -> Bool {
        slot(on: date, profile: profile) != nil
    }

    static func weekIndex(of date: Date, since start: Date) -> Int {
        let calendar = self.calendar
        guard let first = calendar.dateInterval(of: .weekOfYear, for: start)?.start,
              let current = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
        let days = calendar.dateComponents([.day], from: first, to: current).day ?? 0
        return max(0, days / 7)
    }

    // MARK: Workouts

    /// The scheduled workout for `date`, or `nil` on a rest day.
    static func workout(
        on date: Date,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> Workout? {
        guard let daySlot = slot(on: date, profile: profile) else { return nil }
        let week = weekIndex(of: date, since: profile.startDate)
        let day = calendar.startOfDay(for: date)
        let stamp = Int(day.timeIntervalSince1970 / 86_400)
        return assemble(
            id: "plan-\(stamp)",
            title: daySlot.focus.title,
            subtitle: daySlot.focus.subtitle,
            theme: daySlot.focus.theme,
            slots: daySlot.focus.slots,
            profile: profile,
            history: history,
            now: now,
            rotation: week + daySlot.index
        )
    }

    /// The next scheduled workout after `date` (up to a week ahead).
    static func nextWorkout(
        after date: Date,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> (date: Date, workout: Workout)? {
        for offset in 1...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            if let planned = workout(on: day, profile: profile, history: history, now: now) {
                return (day, planned)
            }
        }
        return nil
    }

    static func quick(
        _ kind: QuickKind,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> Workout {
        var adjusted = profile
        let week = weekIndex(of: now, since: profile.startDate)
        switch kind {
        case .short:
            adjusted.equipment = .bodyweight
            return assemble(
                id: "quick-short",
                title: "Short Workout",
                subtitle: "10-minute no-equipment blast",
                theme: .cardio,
                slots: [.legs, .cardio, .chest, .core, .cardio],
                profile: adjusted,
                history: history,
                now: now,
                rotation: week,
                budgetMinutes: 10,
                exerciseCount: 5,
                maxSets: 2,
                restOverride: 20
            )
        case .noEquipment:
            adjusted.equipment = .bodyweight
            return assemble(
                id: "quick-bodyweight",
                title: "Wall Workouts",
                subtitle: "Full body, zero equipment",
                theme: .fullBody,
                slots: DayFocus.fullBodyC.slots,
                profile: adjusted,
                history: history,
                now: now,
                rotation: week + 1
            )
        case .mobility:
            return assemble(
                id: "quick-mobility",
                title: "Mobility & Stretch",
                subtitle: "Loosen up and recover",
                theme: .mobility,
                slots: [.mobility, .mobility, .mobility, .mobility, .mobility, .mobility],
                profile: adjusted,
                history: history,
                now: now,
                rotation: week,
                budgetMinutes: 10,
                exerciseCount: 6,
                maxSets: 2,
                restOverride: 10
            )
        }
    }

    /// Exercises the user could swap in for `planned`.
    static func alternatives(
        for planned: PlannedExercise,
        in workout: Workout,
        profile: UserProfile
    ) -> [Exercise] {
        let current = planned.exercise
        let used = Set(workout.exercises.map { $0.exerciseID })
        return ExerciseLibrary.all
            .filter {
                $0.muscle == current.muscle
                    && !used.contains($0.id)
                    && $0.equipment.rank <= profile.equipment.rank
                    && $0.level.rank <= profile.level.rank
            }
            .sorted { $0.name < $1.name }
    }

    static func replan(
        _ exercise: Exercise,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> PlannedExercise {
        let intensity = AdaptiveEngine.effectiveIntensity(profile: profile, history: history, now: now)
        return plan(exercise, profile: profile, intensity: intensity, history: history)
    }

    // MARK: Building blocks

    static func assemble(
        id: String,
        title: String,
        subtitle: String,
        theme: MuscleGroup,
        slots: [MuscleGroup],
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date,
        rotation: Int,
        budgetMinutes: Int? = nil,
        exerciseCount: Int? = nil,
        maxSets: Int? = nil,
        restOverride: Int? = nil
    ) -> Workout {
        let intensity = AdaptiveEngine.effectiveIntensity(profile: profile, history: history, now: now)
        let budget = budgetMinutes ?? profile.sessionMinutes
        // Build a generous list, then trim to the time budget below.
        let wanted = exerciseCount ?? 8

        var chosen: [Exercise] = []
        for index in 0..<wanted {
            let muscle = slots[index % slots.count]
            if let exercise = pick(muscle: muscle, profile: profile, rotation: rotation + index, excluding: chosen) {
                chosen.append(exercise)
            }
        }

        var planned = chosen.map { plan($0, profile: profile, intensity: intensity, history: history) }
        if let maxSets = maxSets {
            for index in planned.indices { planned[index].sets = min(planned[index].sets, maxSets) }
        }
        if let rest = restOverride {
            for index in planned.indices { planned[index].restSeconds = rest }
        }

        var workout = Workout(id: id, title: title, subtitle: subtitle, theme: theme, exercises: planned)
        // Keep the session inside the time budget.
        while workout.minutes > budget + 2 && workout.exercises.count > 3 {
            workout.exercises.removeLast()
        }
        return workout
    }

    static func pick(
        muscle: MuscleGroup,
        profile: UserProfile,
        rotation: Int,
        excluding: [Exercise]
    ) -> Exercise? {
        let used = Set(excluding.map { $0.id })

        func candidates(maxLevel: Int) -> [Exercise] {
            ExerciseLibrary.all.filter {
                $0.muscle == muscle
                    && !used.contains($0.id)
                    && $0.level.rank <= maxLevel
                    && $0.equipment.rank <= profile.equipment.rank
            }
        }

        // Stay at the user's level; allow at most one tier up if nothing else fits.
        var pool: [Exercise] = []
        for maxLevel in profile.level.rank...min(FitnessLevel.advanced.rank, profile.level.rank + 1) {
            pool = candidates(maxLevel: maxLevel)
            if !pool.isEmpty { break }
        }
        guard !pool.isEmpty else { return nil }

        // Use the best equipment the user has, then skip moves far too easy for their level.
        let bestEquipment = pool.map { $0.equipment.rank }.max() ?? 0
        let preferred = pool.filter { $0.equipment.rank == bestEquipment }
        let suitable = preferred.filter { $0.level.rank >= profile.level.rank - 1 }
        pool = suitable.isEmpty ? preferred : suitable

        // Hardest suitable variation first.
        let ranked = pool.sorted { a, b in
            if a.level.rank != b.level.rank { return a.level.rank > b.level.rank }
            return a.id < b.id
        }
        let top = Array(ranked.prefix(4))
        return top[abs(rotation) % top.count]
    }

    static func plan(
        _ exercise: Exercise,
        profile: UserProfile,
        intensity: Int,
        history: [WorkoutSession]
    ) -> PlannedExercise {
        if exercise.muscle == .mobility {
            return PlannedExercise(exerciseID: exercise.id, sets: 2, target: 30, restSeconds: 10, weightKg: nil)
        }

        var sets = profile.level.baseSets
        if intensity >= 2 { sets += 1 } else if intensity <= -2 { sets -= 1 }
        sets = max(2, min(5, sets))

        let target: Int
        switch exercise.kind {
        case .timed:
            let userRank = profile.level.rank
            var seconds = 30 + 5 * userRank + 10 * (userRank - exercise.level.rank)
            if profile.goal == .loseFat { seconds += 5 }
            target = max(15, min(90, seconds + 5 * intensity))
        case .reps:
            var reps: Int
            if exercise.isLoaded {
                reps = profile.goal.loadedReps(for: profile.level)
            } else {
                reps = 10 + 4 * (profile.level.rank - exercise.level.rank) + profile.goal.bodyweightBonus
            }
            reps += intensity
            target = max(5, min(30, reps))
        }

        let rest = max(20, min(120, profile.goal.restSeconds - 5 * intensity))
        let weight = WeightAdvisor.suggest(for: exercise, profile: profile, history: history)
        return PlannedExercise(exerciseID: exercise.id, sets: sets, target: target, restSeconds: rest, weightKg: weight)
    }
}
