import Foundation

// MARK: - Blocks and deloads

enum Periodization {
    /// Weeks per training block, the last of which is a deload.
    static func blockLength(for level: FitnessLevel) -> Int {
        switch level {
        case .beginner: return 6
        case .intermediate: return 5
        case .advanced: return 4
        }
    }

    /// Reps in reserve to aim for at a position in the block.
    static func repsInReserve(weekInBlock: Int, level: FitnessLevel, isDeload: Bool) -> Int {
        if isDeload { return 4 }
        return max(level == .beginner ? 2 : 1, 3 - weekInBlock)
    }

    static func phase(
        on date: Date,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> WeekPhase {
        let length = blockLength(for: profile.level)
        let weekStart = TrainingCalendar.weekStart(of: date)

        if let forced = profile.deloadWeekStart, TrainingCalendar.sameDay(TrainingCalendar.weekStart(of: forced), weekStart) {
            return WeekPhase(weekInBlock: length - 1, blockLength: length, isDeload: true, repsInReserve: 4)
        }

        var position = TrainingCalendar.weeksBetween(profile.blockStart, and: date) % length
        // After a long break the current week starts a fresh block.
        if let last = history.map({ $0.date }).max(),
           TrainingCalendar.daysBetween(last, now) >= 14,
           TrainingCalendar.sameDay(TrainingCalendar.weekStart(of: now), weekStart) {
            position = 0
        }
        let isDeload = position == length - 1
        return WeekPhase(
            weekInBlock: position,
            blockLength: length,
            isDeload: isDeload,
            repsInReserve: repsInReserve(weekInBlock: position, level: profile.level, isDeload: isDeload)
        )
    }

    /// Which block number the date falls in (drives exercise variety: variants change only at block boundaries).
    static func blockNumber(on date: Date, profile: UserProfile) -> Int {
        let length = blockLength(for: profile.level)
        return profile.blockOffset + max(0, TrainingCalendar.weeksBetween(profile.blockStart, and: date)) / length
    }

    /// Starts a new block at `start`. The block counter keeps moving so exercises rotate instead of repeating the
    /// first block's picks, and the deload schedule stays aligned with the exercise changes.
    static func restartBlock(_ profile: inout UserProfile, at start: Date, on date: Date) {
        profile.blockOffset = blockNumber(on: date, profile: profile) + 1
        profile.blockStart = start
    }
}

// MARK: - Fatigue

enum Recovery {
    /// A log where most working sets missed the planned minimum.
    static func logFailed(_ log: ExerciseLog) -> Bool {
        guard let minimum = log.repMin, !log.sets.isEmpty else { return false }
        guard let exercise = ExerciseLibrary.byID[log.exerciseID] else { return false }
        var sets = log.sets
        if exercise.isLoaded {
            let load = sets.map { $0.weightKg }.max() ?? 0
            sets = sets.filter { $0.weightKg >= load * 0.97 }
        }
        let below = sets.filter { (exercise.kind == .timed ? $0.seconds : $0.reps) < minimum }.count
        return below * 2 >= sets.count
    }

    /// 2 points per "too hard", 2 per session under 75% complete, 1 per failed exercise (max 2 per session),
    /// over the last three sessions in the last two weeks.
    static func fatigueScore(history: [WorkoutSession], now: Date) -> (score: Int, badSessions: Int, sessions: Int) {
        let recent = history
            .filter { $0.date <= now && TrainingCalendar.daysBetween($0.date, now) <= 14 }
            .sorted { $0.date > $1.date }
            .prefix(3)
        var total = 0
        var bad = 0
        for session in recent {
            var points = 0
            if session.feedback == .tooHard { points += 2 }
            if session.completion < 0.75 { points += 2 }
            points += min(2, session.logs.filter { logFailed($0) }.count)
            if points > 0 { bad += 1 }
            total += points
        }
        return (total, bad, recent.count)
    }

    static func shouldDeload(
        profile: UserProfile,
        history: [WorkoutSession],
        phase: WeekPhase,
        now: Date
    ) -> Bool {
        guard !phase.isDeload else { return false }
        // Fatigue needs a baseline: never in the first two weeks, and only with a few sessions behind us.
        guard TrainingCalendar.daysBetween(profile.startDate, now) >= 14, history.count >= 4 else { return false }
        let fatigue = fatigueScore(history: history, now: now)
        guard fatigue.sessions >= 2, fatigue.badSessions >= 2, fatigue.score >= 5 else { return false }
        if let last = profile.deloadWeekStart, TrainingCalendar.daysBetween(last, now) < 21 { return false }
        return true
    }
}

// MARK: - Weekly volume

struct VolumeTarget: Equatable {
    var low: Int
    var high: Int
    var mid: Double { Double(low + high) / 2 }
}

enum VolumePlanner {
    static let muscles: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms, .core]

    /// Hard sets per muscle per week (build-muscle scale; the goal scales it).
    private static func base(_ muscle: MuscleGroup, level: FitnessLevel) -> (Int, Int) {
        let table: [MuscleGroup: [(Int, Int)]] = [
            .chest: [(6, 8), (10, 12), (12, 16)],
            .back: [(6, 8), (10, 12), (12, 16)],
            .legs: [(8, 10), (14, 18), (16, 20)],
            .shoulders: [(4, 6), (6, 8), (8, 12)],
            .arms: [(4, 6), (6, 10), (8, 12)],
            .core: [(4, 6), (6, 8), (6, 10)]
        ]
        return table[muscle]?[level.rank] ?? (0, 0)
    }

    static func target(for muscle: MuscleGroup, level: FitnessLevel, goal: Goal) -> VolumeTarget {
        let (low, high) = base(muscle, level: level)
        guard high > 0 else { return VolumeTarget(low: 0, high: 0) }
        let factor = goal.volumeFactor
        return VolumeTarget(
            low: max(2, Int((Double(low) * factor).rounded())),
            high: max(3, Int((Double(high) * factor).rounded()))
        )
    }

    static func weeklyTargets(for profile: UserProfile) -> [MuscleGroup: VolumeTarget] {
        var result: [MuscleGroup: VolumeTarget] = [:]
        for muscle in muscles {
            result[muscle] = target(for: muscle, level: profile.level, goal: profile.goal)
        }
        return result
    }

    /// Completed sets per muscle in the week containing `date`.
    static func completedSets(in sessions: [WorkoutSession], weekContaining date: Date) -> [MuscleGroup: Int] {
        let start = TrainingCalendar.weekStart(of: date)
        var result: [MuscleGroup: Int] = [:]
        for session in sessions where TrainingCalendar.sameDay(TrainingCalendar.weekStart(of: session.date), start) {
            for log in session.logs {
                guard let muscle = ExerciseLibrary.byID[log.exerciseID]?.muscle else { continue }
                result[muscle, default: 0] += log.sets.count
            }
        }
        return result
    }
}
