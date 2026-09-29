import Foundation

struct RepRange: Equatable {
    var min: Int
    var max: Int
}

/// What to prescribe for the next time an exercise is done.
struct Decision: Equatable {
    var target: Int
    var repMin: Int
    var repMax: Int
    var weightKg: Double?
    var reason: String?
    /// The exercise is maxed out and nothing harder is available: add a set.
    var addSet = false
}

enum Comeback {
    /// Load multiplier after time off.
    static func factor(daysSinceLast days: Int) -> Double {
        switch days {
        case ..<10: return 1.0
        case 10..<21: return 0.95
        case 21..<35: return 0.85
        case 35..<60: return 0.75
        default: return 0.65
        }
    }

    static func setsToRemove(daysSinceLast days: Int) -> Int { days >= 14 ? 1 : 0 }

    static func percentLighter(daysSinceLast days: Int) -> Int {
        Int(((1 - factor(daysSinceLast: days)) * 100).rounded())
    }
}

enum Progression {
    static let deloadSetFactor = 0.6
    static let deloadLoadFactor = 0.9
    static let barbellIDs: Set<String> = [
        "bench_press", "back_squat", "deadlift", "overhead_press", "barbell_row", "barbell_curl"
    ]

    // MARK: Prescription basics

    static func repRange(for exercise: Exercise, goal: Goal, level: FitnessLevel) -> RepRange {
        if exercise.muscle == .mobility { return RepRange(min: 30, max: 30) }
        if exercise.kind == .timed {
            if exercise.muscle == .cardio { return RepRange(min: 30, max: 45) }
            return level == .beginner ? RepRange(min: 15, max: 30) : RepRange(min: 20, max: 45)
        }
        if exercise.isLoaded {
            if exercise.isCompound {
                switch goal {
                case .buildMuscle:
                    return level == .beginner ? RepRange(min: 8, max: 12) : RepRange(min: 6, max: 10)
                case .getStronger:
                    // Heavy low-rep work is for the barbell main lifts only; other compounds stay 6-8.
                    if barbellIDs.contains(exercise.id) || exercise.id == "pullup" {
                        switch level {
                        case .beginner: return RepRange(min: 6, max: 8)
                        case .intermediate: return RepRange(min: 5, max: 8)
                        case .advanced: return RepRange(min: 3, max: 6)
                        }
                    }
                    return level == .advanced ? RepRange(min: 5, max: 8) : RepRange(min: 6, max: 8)
                case .loseFat: return RepRange(min: 10, max: 15)
                case .stayFit: return RepRange(min: 8, max: 12)
                }
            }
            switch goal {
            case .buildMuscle: return RepRange(min: 10, max: 15)
            case .getStronger: return RepRange(min: 8, max: 12)
            case .loseFat: return RepRange(min: 12, max: 20)
            case .stayFit: return RepRange(min: 10, max: 15)
            }
        }
        if exercise.muscle == .cardio { return RepRange(min: 8, max: 15) }
        if exercise.isBodyweightLadderMember && exercise.isCompound {
            switch goal {
            case .buildMuscle: return RepRange(min: 8, max: 15)
            case .getStronger: return RepRange(min: 5, max: 10)
            case .loseFat: return RepRange(min: 10, max: 15)
            case .stayFit: return RepRange(min: 8, max: 12)
            }
        }
        return goal == .loseFat ? RepRange(min: 12, max: 20) : RepRange(min: 10, max: 20)
    }

    static func rest(for exercise: Exercise, range: RepRange, goal: Goal, age: Int) -> Int {
        if exercise.muscle == .mobility { return 10 }
        var rest: Double
        if exercise.muscle == .cardio {
            rest = 30
        } else if exercise.kind == .timed {
            rest = 40
        } else if exercise.isLoaded {
            if exercise.isCompound {
                rest = range.max <= 6 ? 150 : (range.max <= 10 ? 120 : 90)
            } else {
                rest = 60
            }
        } else {
            rest = exercise.isCompound ? 60 : 45
        }
        if goal == .loseFat && exercise.muscle != .cardio { rest = max(30, rest * 0.67) }
        if age >= 50 { rest *= 1.15 }
        return Int((rest / 5).rounded()) * 5
    }

    // MARK: Loads

    static func step(for exercise: Exercise, at load: Double) -> Double {
        if barbellIDs.contains(exercise.id) { return exercise.muscle == .legs ? 5 : 2.5 }
        if exercise.equipment == .fullGym { return exercise.muscle == .legs ? 5 : 2.5 }
        if load < 10 { return 1 }
        return load < 30 ? 2 : 2.5
    }

    static func minimumLoad(for exercise: Exercise) -> Double {
        if barbellIDs.contains(exercise.id) { return 20 }
        return exercise.equipment == .fullGym ? 5 : 1
    }

    /// Rounds to the equipment's load step. `clampToMinimum` lifts results to the smallest sensible load (an empty
    /// barbell); it is for choosing a *starting* load only. Loads derived from what the person actually lifted must
    /// not be pushed up by it (a deload above the last weight, a "+5 kg" jump instead of +2.5).
    static func roundLoad(_ load: Double, for exercise: Exercise, down: Bool = false, clampToMinimum: Bool = true) -> Double {
        let s = step(for: exercise, at: load)
        let steps = down ? (load / s).rounded(.down) : (load / s).rounded()
        return max(clampToMinimum ? minimumLoad(for: exercise) : s, steps * s)
    }

    static func dumbbellCap(for exercise: Exercise, profile: UserProfile) -> Double? {
        guard exercise.equipment == .dumbbells, profile.maxDumbbellKg > 0 else { return nil }
        return profile.maxDumbbellKg
    }

    /// First-session weight: typical ratio x body weight x level x sex x age x 0.85 (start light).
    static func initialLoad(for exercise: Exercise, profile: UserProfile) -> Double? {
        guard let ratio = exercise.loadRatio else { return nil }
        let upper = [MuscleGroup.chest, .back, .shoulders, .arms].contains(exercise.muscle)
        let sexFactor: Double
        switch profile.sex {
        case .male: sexFactor = 1.0
        case .female: sexFactor = upper ? 0.65 : 0.85
        case .unspecified: sexFactor = upper ? 0.83 : 0.92
        }
        let ageFactor = profile.age >= 65 ? 0.75 : (profile.age >= 50 ? 0.9 : 1.0)
        let raw = ratio * profile.weightKg * profile.level.weightFactor * sexFactor * ageFactor * 0.85
        var load = roundLoad(raw, for: exercise)
        if let cap = dumbbellCap(for: exercise, profile: profile) { load = min(load, cap) }
        return load
    }

    /// Epley estimate. Only meaningful for sets of up to 15 reps.
    static func estimatedOneRepMax(weightKg: Double, reps: Int) -> Double? {
        guard weightKg > 0, reps >= 1, reps <= 15 else { return nil }
        return weightKg * (1 + Double(reps) / 30)
    }

    // MARK: History helpers

    /// The most recent logs of one exercise (newest first), skipping empty ones.
    static func recentLogs(for exerciseID: String, in history: [WorkoutSession], limit: Int) -> [ExerciseLog] {
        var result: [ExerciseLog] = []
        for session in history.sorted(by: { $0.date > $1.date }) {
            if let log = session.logs.first(where: { $0.exerciseID == exerciseID && !$0.sets.isEmpty }) {
                result.append(log)
                if result.count == limit { break }
            }
        }
        return result
    }

    /// Date of the most recent logged session containing this exercise.
    static func lastDate(for exerciseID: String, in history: [WorkoutSession]) -> Date? {
        history
            .filter { $0.logs.contains(where: { $0.exerciseID == exerciseID && !$0.sets.isEmpty }) }
            .map { $0.date }
            .max()
    }

    /// Date of the most recent session that trained this exercise *or another variation of the same movement*.
    /// Exercises rotate between blocks, so time off is judged by the movement, not by one specific variant.
    static func lastDate(forMovementOf exercise: Exercise, in history: [WorkoutSession]) -> Date? {
        history
            .filter { session in
                session.logs.contains { log in
                    guard !log.sets.isEmpty, let logged = ExerciseLibrary.byID[log.exerciseID] else { return false }
                    return logged.id == exercise.id || logged.pattern == exercise.pattern
                }
            }
            .map { $0.date }
            .max()
    }

    /// True when there was no gap of two weeks or more between `date` and `now` (counting the sessions in between).
    /// Someone who kept training, but dropped or rotated an exercise, is not coming back from a break.
    static func trainedContinuously(since date: Date, in history: [WorkoutSession], now: Date) -> Bool {
        let dates = history.map { $0.date }.filter { $0 > date && $0 <= now }.sorted() + [now]
        var previous = date
        for next in dates {
            if TrainingCalendar.daysBetween(previous, next) >= 14 { return false }
            previous = next
        }
        return true
    }

    private static func values(_ log: ExerciseLog, timed: Bool) -> [Int] {
        log.sets.map { timed ? $0.seconds : $0.reps }
    }

    private static func didEnoughSets(_ log: ExerciseLog, done: Int) -> Bool {
        done >= max(2, log.targetSets - 1)
    }

    /// Did every (working) set reach the top of the range?
    static func reachedTop(_ log: ExerciseLog, exercise: Exercise, range: RepRange) -> Bool {
        let timed = exercise.kind == .timed
        if exercise.isLoaded {
            let load = log.sets.map { $0.weightKg }.max() ?? 0
            let sets = log.sets.filter { $0.weightKg >= load * 0.97 }
            return didEnoughSets(log, done: sets.count) && sets.allSatisfy { $0.reps >= range.max }
        }
        let hi = max(range.max, log.repMax ?? range.max)
        let v = values(log, timed: timed)
        return didEnoughSets(log, done: v.count) && v.allSatisfy { $0 >= hi }
    }

    /// Did most sets miss the bottom of the range?
    /// - Parameter tolerance: how far under the minimum still counts as a miss (used to avoid stepping back a
    ///   rung on a marginal miss).
    static func failed(_ log: ExerciseLog, exercise: Exercise, range: RepRange, tolerance: Int = 0) -> Bool {
        let timed = exercise.kind == .timed
        let floor = max(1, range.min - tolerance)
        if exercise.isLoaded {
            let load = log.sets.map { $0.weightKg }.max() ?? 0
            let sets = log.sets.filter { $0.weightKg >= load * 0.97 }
            guard !sets.isEmpty else { return false }
            return sets.filter { $0.reps < floor }.count * 2 >= sets.count
        }
        let v = values(log, timed: timed)
        guard !v.isEmpty else { return false }
        return v.filter { $0 < floor }.count * 2 >= v.count
    }

    // MARK: The decision

    static func decide(
        exercise: Exercise,
        profile: UserProfile,
        history: [WorkoutSession],
        range: RepRange,
        holdLoad: Bool = false
    ) -> Decision {
        let logs = recentLogs(for: exercise.id, in: history, limit: 2)
        guard let last = logs.first else { return firstTime(exercise, profile, range) }

        if exercise.isLoaded {
            let load = last.sets.map { $0.weightKg }.max() ?? 0
            if load <= 0 { return firstTime(exercise, profile, range) }
            var decision = decideLoaded(exercise, profile, range, logs: logs, load: load)
            if holdLoad, let planned = decision.weightKg, planned > load {
                decision.weightKg = load
                decision.target = max(range.min, min(range.max, last.sets.map { $0.reps }.min() ?? range.min))
                decision.reason = L("You're not feeling great today: same weight, no jump.")
            }
            return decision
        }
        return decideBodyweight(exercise, profile, range, last: last, holdLoad: holdLoad)
    }

    private static func firstTime(_ exercise: Exercise, _ profile: UserProfile, _ range: RepRange) -> Decision {
        if exercise.isLoaded {
            return Decision(
                target: (range.min + range.max) / 2,
                repMin: range.min,
                repMax: range.max,
                weightKg: initialLoad(for: exercise, profile: profile),
                reason: L("First time: a light starting weight. Change it if it feels off.")
            )
        }
        return Decision(
            target: range.min,
            repMin: range.min,
            repMax: range.max,
            weightKg: nil,
            reason: L("First time: start at a comfortable number and add a little each session.")
        )
    }

    private static func decideLoaded(
        _ exercise: Exercise,
        _ profile: UserProfile,
        _ range: RepRange,
        logs: [ExerciseLog],
        load: Double
    ) -> Decision {
        let last = logs[0]
        let sets = last.sets.filter { $0.weightKg >= load * 0.97 }
        let reps = sets.map { $0.reps }
        let n = sets.count
        let minReps = reps.min() ?? 0
        let effort = last.effort ?? .good
        let enough = didEnoughSets(last, done: n)
        let stepKg = step(for: exercise, at: load)
        let cap = dumbbellCap(for: exercise, profile: profile)
        let units = profile.units

        func decision(_ target: Int, _ weight: Double, _ reason: String, repMax: Int? = nil) -> Decision {
            Decision(target: target, repMin: range.min, repMax: repMax ?? range.max, weightKg: weight, reason: reason)
        }

        let hitTop = reps.allSatisfy { $0 >= range.max }
        let easyAlmost = effort == .easy && reps.allSatisfy { $0 >= range.max - 1 }

        if enough && (hitTop || easyAlmost) {
            if effort == .hard && hitTop {
                return decision(range.max, load,
                                L("You reached {0} reps but it felt hard: repeat this weight to lock it in.", range.max))
            }
            let beatBy3 = reps.allSatisfy { $0 >= range.max + 3 } && effort != .hard
            var next = load + stepKg * (beatBy3 ? 2 : 1)
            if let cap = cap, next > cap {
                if load >= cap - 0.001 {
                    let newMax = min(20, max(range.max, minReps + 2))
                    let target = min(newMax, minReps + 1)
                    return decision(target, load,
                                    L("This is your heaviest dumbbell, so keep adding reps (up to {0}).", newMax),
                                    repMax: newMax)
                }
                next = cap
            }
            next = roundLoad(next, for: exercise, clampToMinimum: false)
            if let cap = cap { next = min(next, cap) }
            let amount = units.formatWeight(next - load)
            let sentence = hitTop
                ? L("Up {0}: you hit {1} reps on every set.", amount, range.max)
                : L("Up {0}: you reached the top of the range and it felt easy.", amount)
            return decision(range.min, next, sentence)
        }

        if !enough {
            return decision(range.min, load, L("You skipped some sets last time: same weight, get all your sets in."))
        }

        let below = reps.filter { $0 < range.min }.count
        if below == 0 {
            let target = min(range.max, minReps + 1)
            return decision(target, load, L("Same weight: aim for {0} reps on every set.", target))
        }
        if below * 2 >= n {
            let severe = minReps <= range.min - 4
            var previousFailed = false
            if logs.count > 1 {
                let prev = logs[1]
                let prevLoad = prev.sets.map { $0.weightKg }.max() ?? 0
                previousFailed = prevLoad >= load * 0.97 && failed(prev, exercise: exercise, range: range)
            }
            if severe || previousFailed {
                let lighter = roundLoad(load * 0.9, for: exercise, down: true, clampToMinimum: false)
                let why = (severe && !previousFailed)
                    ? L("That was much heavier than planned: dropping about 10%.")
                    : L("Two tough sessions in a row: dropping about 10% to rebuild.")
                return decision(range.min, min(lighter, load), why)
            }
            return decision(range.min, load, L("You missed the minimum reps: repeat this weight and beat it."))
        }
        return decision(range.min, load, L("One set fell short: repeat the weight and get every set."))
    }

    private static func decideBodyweight(
        _ exercise: Exercise,
        _ profile: UserProfile,
        _ range: RepRange,
        last: ExerciseLog,
        holdLoad: Bool
    ) -> Decision {
        let timed = exercise.kind == .timed
        let v = values(last, timed: timed)
        let minV = v.min() ?? 0
        let effort = last.effort ?? .good
        let hiEff = max(range.max, last.repMax ?? range.max)
        let enough = didEnoughSets(last, done: v.count)
        let tolerance = timed ? 5 : 1
        let hitTop = enough && v.allSatisfy { $0 >= hiEff }
        let easyAlmost = enough && effort == .easy && v.allSatisfy { $0 >= hiEff - tolerance }

        func decision(_ target: Int, _ reason: String, repMax: Int? = nil, addSet: Bool = false) -> Decision {
            Decision(target: target, repMin: range.min, repMax: repMax ?? hiEff, weightKg: nil, reason: reason, addSet: addSet)
        }

        if (hitTop || easyAlmost) && !holdLoad {
            // Moving to a harder variation is decided when the session is recorded. If we are still here,
            // no harder variation is available, so extend the range instead.
            let ceiling = timed ? 90 : 25
            if hiEff >= ceiling {
                return decision(hiEff, L("You've maxed this out: add a set, or switch to a harder variation."), addSet: true)
            }
            let newMax = min(ceiling, hiEff + (timed ? 10 : 3))
            let target = min(newMax, hiEff + (timed ? 5 : 1))
            let extended = timed
                ? L("You reached the top and there's no harder variation available: adding seconds.")
                : L("You reached the top and there's no harder variation available: adding reps.")
            return decision(target, extended, repMax: newMax)
        }
        if !enough {
            return decision(range.min, L("You skipped some sets last time: get all your sets in."))
        }
        let below = v.filter { $0 < range.min }.count
        if below == 0 {
            let target = min(hiEff, minV + (timed ? 5 : 1))
            return decision(target, timed ? L("Aim for {0} seconds on every set.", target) : L("Aim for {0} reps on every set.", target))
        }
        return decision(range.min, L("Below the minimum last time: repeat and build back up."))
    }
}
