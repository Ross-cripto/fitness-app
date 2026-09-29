import Foundation

/// A training day's structure: movement patterns in priority order (big lifts first).
enum SessionFocus: String, CaseIterable {
    case fullBodyA, fullBodyB, fullBodyC, upperA, upperB, lowerA, lowerB, push, pull, legs

    var title: String {
        switch self {
        case .fullBodyA, .fullBodyB, .fullBodyC: return L("Full Body")
        case .upperA, .upperB: return L("Upper Body")
        case .lowerA, .lowerB: return L("Lower Body")
        case .push: return L("Push Day")
        case .pull: return L("Pull Day")
        case .legs: return L("Leg Day")
        }
    }

    var subtitle: String {
        switch self {
        case .fullBodyA: return L("Squat and press emphasis")
        case .fullBodyB: return L("Hinge and pull emphasis")
        case .fullBodyC: return L("Balanced total-body work")
        case .upperA: return L("Chest, back, shoulders, arms")
        case .upperB: return L("Back-focused upper body")
        case .lowerA: return L("Quads, glutes, core")
        case .lowerB: return L("Hamstrings, glutes, calves")
        case .push: return L("Chest, shoulders, triceps")
        case .pull: return L("Back and biceps")
        case .legs: return L("Legs and core")
        }
    }

    var theme: MuscleGroup {
        switch self {
        case .fullBodyA, .fullBodyB, .fullBodyC: return .fullBody
        case .upperA, .upperB, .push: return .chest
        case .pull: return .back
        case .lowerA, .lowerB, .legs: return .legs
        }
    }

    var slots: [Pattern] {
        switch self {
        case .fullBodyA:
            return [.squat, .horizontalPush, .horizontalPull, .hinge, .verticalPush, .coreStability, .biceps, .triceps, .calves, .cardio]
        case .fullBodyB:
            return [.hinge, .verticalPull, .horizontalPush, .lunge, .horizontalPull, .coreFlexion, .triceps, .biceps, .shoulderIsolation, .cardio]
        case .fullBodyC:
            return [.squat, .horizontalPull, .verticalPush, .hinge, .horizontalPush, .coreStability, .biceps, .triceps, .lunge, .cardio]
        case .upperA:
            return [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .horizontalPush, .horizontalPull, .triceps, .biceps, .shoulderIsolation, .coreStability]
        case .upperB:
            return [.horizontalPull, .horizontalPush, .verticalPull, .verticalPush, .chestIsolation, .horizontalPull, .biceps, .triceps, .shoulderIsolation, .coreFlexion]
        case .lowerA:
            return [.squat, .hinge, .lunge, .calves, .coreStability, .coreFlexion, .squat, .cardio]
        case .lowerB:
            return [.hinge, .squat, .lunge, .calves, .coreFlexion, .coreRotation, .hinge, .cardio]
        case .push:
            return [.horizontalPush, .verticalPush, .horizontalPush, .shoulderIsolation, .triceps, .triceps, .chestIsolation, .coreStability]
        case .pull:
            return [.verticalPull, .horizontalPull, .horizontalPull, .rearDelt, .biceps, .biceps, .coreFlexion, .coreStability]
        case .legs:
            return [.squat, .hinge, .lunge, .calves, .squat, .hinge, .coreStability, .coreFlexion, .cardio]
        }
    }

    /// Muscles trained by this day.
    var muscles: Set<MuscleGroup> { Set(slots.map { $0.muscle }) }
}

enum QuickKind: String, CaseIterable, Identifiable {
    case short, noEquipment, mobility

    var id: String { rawValue }
}

enum PlanGenerator {
    // MARK: Schedule

    static var calendar: Calendar { TrainingCalendar.calendar }

    static func clampedDays(_ days: Int) -> Int { max(1, min(6, days)) }

    /// Sensible default weekdays (1 = Sunday ... 7 = Saturday) for a number of training days.
    static func defaultWeekdays(forDays days: Int) -> [Int] {
        switch clampedDays(days) {
        case 1: return [2]
        case 2: return [2, 5]
        case 3: return [2, 4, 6]
        case 4: return [2, 3, 5, 6]
        case 5: return [2, 3, 4, 6, 7]
        default: return [2, 3, 4, 5, 6, 7]
        }
    }

    /// The person's training weekdays in Monday-first order.
    static func weekdays(for profile: UserProfile) -> [Int] {
        let chosen = Array(Set(profile.trainingWeekdays.filter { (1...7).contains($0) }))
        guard !chosen.isEmpty else { return defaultWeekdays(forDays: 3) }
        let ordered = chosen.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }
        return Array(ordered.prefix(6))
    }

    static func split(for profile: UserProfile) -> [SessionFocus] {
        switch clampedDays(weekdays(for: profile).count) {
        case 1: return [.fullBodyA]
        case 2: return [.fullBodyA, .fullBodyB]
        case 3: return profile.level == .advanced ? [.push, .pull, .legs] : [.fullBodyA, .fullBodyB, .fullBodyC]
        case 4: return [.upperA, .lowerA, .upperB, .lowerB]
        case 5: return [.push, .pull, .legs, .upperA, .lowerA]
        default: return [.push, .pull, .legs, .push, .pull, .legs]
        }
    }

    static func slot(on date: Date, profile: UserProfile) -> (focus: SessionFocus, index: Int)? {
        let weekday = calendar.component(.weekday, from: date)
        guard let index = weekdays(for: profile).firstIndex(of: weekday) else { return nil }
        return (split(for: profile)[index], index)
    }

    static func isTrainingDay(_ date: Date, profile: UserProfile) -> Bool {
        slot(on: date, profile: profile) != nil
    }

    /// How many sessions per week train each muscle.
    static func muscleFrequency(for profile: UserProfile) -> [MuscleGroup: Int] {
        var result: [MuscleGroup: Int] = [:]
        for focus in split(for: profile) {
            for muscle in focus.muscles { result[muscle, default: 0] += 1 }
        }
        return result
    }

    // MARK: Workouts

    /// The scheduled workout for `date`, or `nil` on a rest day.
    static func workout(
        on date: Date,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date(),
        readiness: Readiness = .normal
    ) -> Workout? {
        guard let daySlot = slot(on: date, profile: profile) else { return nil }
        return build(focus: daySlot.focus, sessionIndex: daySlot.index, on: date, profile: profile, history: history, now: now, readiness: readiness)
    }

    /// The scheduled workouts of the week containing `date`.
    static func week(
        containing date: Date,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> [(date: Date, workout: Workout)] {
        let start = TrainingCalendar.weekStart(of: date)
        return (0..<7).compactMap { offset -> (date: Date, workout: Workout)? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let planned = workout(on: day, profile: profile, history: history, now: now) else { return nil }
            return (day, planned)
        }
    }

    /// Planned working sets per muscle across the week.
    static func plannedSets(in week: [(date: Date, workout: Workout)]) -> [MuscleGroup: Int] {
        var result: [MuscleGroup: Int] = [:]
        for item in week {
            for planned in item.workout.exercises {
                result[planned.exercise.muscle, default: 0] += planned.sets
            }
        }
        return result
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

    // MARK: Building a session

    private struct Context {
        var profile: UserProfile
        var history: [WorkoutSession]
        var now: Date
        var phase: WeekPhase?
        var readiness: Readiness
        var daysOff: Int
        var comebackFactor: Double
    }

    private static func context(
        profile: UserProfile,
        history: [WorkoutSession],
        date: Date,
        now: Date,
        readiness: Readiness,
        usePhase: Bool
    ) -> Context {
        // A session dated in the future (wrong clock, bad import) is not "the last workout".
        let history = history.filter { $0.date <= now }
        let last = history.map { $0.date }.max()
        let daysOff = last.map { TrainingCalendar.daysBetween($0, now) } ?? 0
        let soon = TrainingCalendar.daysBetween(now, date) <= 7
        let factor = (last != nil && soon) ? Comeback.factor(daysSinceLast: daysOff) : 1.0
        return Context(
            profile: profile,
            history: history,
            now: now,
            phase: usePhase ? Periodization.phase(on: date, profile: profile, history: history, now: now) : nil,
            readiness: readiness,
            daysOff: daysOff,
            comebackFactor: factor
        )
    }

    private static func build(
        focus: SessionFocus,
        sessionIndex: Int,
        on date: Date,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date,
        readiness: Readiness
    ) -> Workout {
        let ctx = context(profile: profile, history: history, date: date, now: now, readiness: readiness, usePhase: true)
        let blockNo = Periodization.blockNumber(on: date, profile: profile)

        // Aim for the middle of the evidence range. If that leaves a lot of the session unused, use the top of it.
        var result = compose(focus: focus, sessionIndex: sessionIndex, ctx: ctx, blockNumber: blockNo, useHighEnd: false)
        let budget = profile.sessionMinutes * 60
        if Double(result.seconds) < 0.8 * Double(budget) {
            let high = compose(focus: focus, sessionIndex: sessionIndex, ctx: ctx, blockNumber: blockNo, useHighEnd: true)
            if high.seconds > result.seconds { result = high }
        }

        var note: String?
        if ctx.phase?.isDeload == true {
            note = L("Deload week: fewer sets and lighter weights so your body can recover and come back stronger.")
        } else if ctx.comebackFactor < 1 {
            note = L("Welcome back after {0} days: lighter weights to ease in.", ctx.daysOff)
        } else if readiness == .low {
            note = L("Easy day: one set fewer and no weight jumps.")
        }

        let day = calendar.dateComponents([.year, .month, .day], from: date)
        let stamp = String(format: "%04d%02d%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
        return Workout(
            id: "plan-\(stamp)",
            title: focus.title,
            subtitle: focus.subtitle,
            theme: focus.theme,
            warmup: result.drills,
            exercises: result.planned,
            phase: ctx.phase,
            note: note,
            date: date
        )
    }

    private static func compose(
        focus: SessionFocus,
        sessionIndex: Int,
        ctx: Context,
        blockNumber blockNo: Int,
        useHighEnd: Bool
    ) -> (planned: [PlannedExercise], drills: [PlannedExercise], seconds: Int) {
        let profile = ctx.profile

        // 1. How many hard sets each muscle should get in this session.
        let sessions = split(for: profile)
        let targets = VolumePlanner.weeklyTargets(for: profile)
        var wanted: [MuscleGroup: Int] = [:]
        for (muscle, target) in targets where target.high > 0 {
            let days = sessions.indices.filter { sessions[$0].muscles.contains(muscle) }
            guard let rank = days.firstIndex(of: sessionIndex) else { continue }
            let weekly = useHighEnd ? Double(target.high) : target.mid
            // A muscle only needs as many sessions as its weekly target justifies (2+ sets each), spread
            // evenly across the sessions that could train it.
            let needed = max(1, min(days.count, Int((weekly / 2).rounded(.down))))
            let includes = ((rank + 1) * needed) / days.count > (rank * needed) / days.count
            guard includes else { continue }
            wanted[muscle] = max(2, Int((weekly / Double(needed)).rounded()))
        }

        // 2. Walk the template, choosing an exercise per pattern until each muscle has its sets.
        var chosen: [(exercise: Exercise, sets: Int)] = []
        var allocated: [MuscleGroup: Int] = [:]
        var used = Set<String>()
        var occurrences: [Pattern: Int] = [:]

        for pattern in focus.slots where pattern.muscle != .cardio {
            let muscle = pattern.muscle
            guard let want = wanted[muscle] else { continue }
            let have = allocated[muscle] ?? 0
            let remaining = want - have
            // A single leftover set is not worth another exercise.
            if remaining <= 0 || (remaining < 2 && have > 0) { continue }
            let occurrence = occurrences[pattern, default: 0]
            guard let exercise = pick(pattern, occurrence: occurrence, profile: profile, blockNumber: blockNo, sessionIndex: sessionIndex, used: used) else { continue }
            occurrences[pattern] = occurrence + 1
            used.insert(exercise.id)

            // Spread leg work over several movements instead of piling sets on one.
            let maxSets = exercise.isCompound ? (muscle == .legs ? 3 : 4) : 3
            var sets = min(remaining, maxSets)
            if remaining - sets == 1 && sets < maxSets { sets += 1 }
            sets = max(2, sets)
            allocated[muscle, default: 0] += sets
            chosen.append((exercise, sets))
        }

        // Cardio finisher for fat loss / general fitness.
        let cardioSets = profile.goal == .loseFat ? 3 : (profile.goal == .stayFit ? 2 : 0)
        if cardioSets > 0, focus.slots.contains(.cardio),
           let cardio = pick(.cardio, occurrence: 0, profile: profile, blockNumber: blockNo, sessionIndex: sessionIndex, used: used) {
            used.insert(cardio.id)
            chosen.append((cardio, cardioSets))
        }

        // Always at least three exercises.
        if chosen.count < 3 {
            for pattern in focus.slots where pattern.muscle != .cardio {
                if chosen.count >= 3 { break }
                let occurrence = occurrences[pattern, default: 0]
                if let exercise = pick(pattern, occurrence: occurrence, profile: profile, blockNumber: blockNo, sessionIndex: sessionIndex, used: used) {
                    occurrences[pattern] = occurrence + 1
                    used.insert(exercise.id)
                    chosen.append((exercise, 2))
                }
            }
        }

        // Very restricted people (few exercises available) get safe core, leg or cardio work as filler.
        if chosen.count < 3 {
            let fillers: [Pattern] = [.coreStability, .coreFlexion, .squat, .hinge, .lunge, .calves, .coreRotation, .cardio]
            for pattern in fillers {
                if chosen.count >= 3 { break }
                if let exercise = pick(pattern, occurrence: 0, profile: profile, blockNumber: blockNo, sessionIndex: sessionIndex, used: used) {
                    used.insert(exercise.id)
                    chosen.append((exercise, 2))
                }
            }
        }

        // 3. Session-level adjustments to the sets.
        var adjusted = chosen.map { (exercise: $0.exercise, sets: $0.sets) }
        if profile.age >= 65 { adjusted = adjusted.map { ($0.exercise, min($0.sets, 3)) } }
        if profile.intensity >= 2 {
            var bumped = 0
            for i in adjusted.indices where adjusted[i].exercise.isCompound && bumped < 2 {
                adjusted[i].sets = min(5, adjusted[i].sets + 1)
                bumped += 1
            }
        } else if profile.intensity <= -2 {
            for i in adjusted.indices where adjusted[i].exercise.isCompound {
                adjusted[i].sets = max(2, adjusted[i].sets - 1)
            }
        }
        if ctx.phase?.isDeload == true {
            for i in adjusted.indices {
                adjusted[i].sets = max(2, Int((Double(adjusted[i].sets) * Progression.deloadSetFactor).rounded()))
            }
        }
        if Comeback.setsToRemove(daysSinceLast: ctx.daysOff) > 0 && ctx.comebackFactor < 1 {
            for i in adjusted.indices where adjusted[i].sets >= 3 { adjusted[i].sets -= 1 }
        }
        if ctx.readiness == .low {
            for i in adjusted.indices where adjusted[i].sets >= 3 { adjusted[i].sets -= 1 }
        }

        // 4. Prescriptions.
        var planned = adjusted.map { prescribe($0.exercise, sets: $0.sets, ctx: ctx) }

        // 5. Ramp-up sets for the first heavy compound (they take time, so they count toward the budget).
        addRampSets(&planned)

        // 6. Fit the time budget.
        let drills = warmupDrills(for: planned.map { $0.exercise }, profile: profile)
        let warmupSeconds = drills.reduce(0) { $0 + $1.totalSeconds }
        fit(&planned, toSeconds: profile.sessionMinutes * 60 - warmupSeconds)

        let seconds = (drills + planned).reduce(0) { $0 + $1.totalSeconds }
        return (planned, drills, seconds)
    }

    // MARK: Prescription

    private static func prescribe(_ exercise: Exercise, sets initialSets: Int, ctx: Context) -> PlannedExercise {
        let profile = ctx.profile
        let range = Progression.repRange(for: exercise, goal: profile.goal, level: profile.level)
        var decision = Progression.decide(
            exercise: exercise, profile: profile, history: ctx.history, range: range, holdLoad: ctx.readiness == .low
        )
        var sets = initialSets
        if decision.addSet && ctx.phase?.isDeload != true { sets = min(5, sets + 1) }
        var reason = decision.reason
        let hasHistory = Progression.lastDate(for: exercise.id, in: ctx.history) != nil
        // After a break (a gap of two weeks or more) every movement eases back in, not just the first session back.
        // Time off is judged per movement (this exercise or a variation of it), and rotating or dropping an exercise
        // while still training regularly is not a break.
        let lastMovementDate = Progression.lastDate(forMovementOf: exercise, in: ctx.history)
        let daysSince = lastMovementDate.map { TrainingCalendar.daysBetween($0, ctx.now) } ?? 0
        let onBreak = lastMovementDate.map { !Progression.trainedContinuously(since: $0, in: ctx.history, now: ctx.now) } ?? false
        let exerciseComeback = (hasHistory && onBreak) ? Comeback.factor(daysSinceLast: daysSince) : 1.0

        if var weight = decision.weightKg, hasHistory {
            if exerciseComeback < 1 {
                weight = min(weight, Progression.roundLoad(weight * exerciseComeback, for: exercise, down: true, clampToMinimum: false))
                decision.target = decision.repMin
                let pct = Comeback.percentLighter(daysSinceLast: daysSince)
                reason = L("Comeback: about {0}% lighter after {1} days off.", pct, daysSince)
            }
            if ctx.phase?.isDeload == true {
                // Deload from what was actually lifted, never from a load that progression just raised.
                let lifted = Progression.recentLogs(for: exercise.id, in: ctx.history, limit: 1).first?
                    .sets.map { $0.weightKg }.max() ?? 0
                let base = lifted > 0 ? min(weight, lifted) : weight
                weight = min(base, Progression.roundLoad(base * Progression.deloadLoadFactor, for: exercise, down: true, clampToMinimum: false))
                reason = L("Deload week: a lighter weight to recover.")
            }
            if let cap = Progression.dumbbellCap(for: exercise, profile: profile), weight > cap { weight = cap }
            decision.weightKg = weight
        } else if hasHistory {
            if ctx.phase?.isDeload == true {
                reason = L("Deload week: fewer sets to recover.")
            } else if exerciseComeback < 1 {
                decision.target = decision.repMin
                reason = L("Comeback: ease back in with a comfortable number.")
            }
        }

        var rest = Progression.rest(for: exercise, range: range, goal: profile.goal, age: profile.age)
        if ctx.readiness == .low { rest = Int((Double(rest) * 1.15 / 5).rounded()) * 5 }
        let rir = exercise.muscle == .mobility ? nil : (ctx.phase?.repsInReserve).map { $0 + (profile.age >= 50 ? 1 : 0) }

        if exercise.muscle == .mobility { sets = 2 }

        return PlannedExercise(
            exerciseID: exercise.id,
            sets: sets,
            target: decision.target,
            repMin: decision.repMin,
            repMax: decision.repMax,
            restSeconds: rest,
            weightKg: decision.weightKg,
            repsInReserve: rir,
            reason: reason
        )
    }

    /// Re-prescribe one exercise (used when the person swaps it).
    static func replan(
        _ exercise: Exercise,
        profile: UserProfile,
        history: [WorkoutSession],
        sets: Int = 3,
        on date: Date = Date(),
        now: Date = Date(),
        readiness: Readiness = .normal
    ) -> PlannedExercise {
        let ctx = context(profile: profile, history: history, date: date, now: now, readiness: readiness, usePhase: true)
        return prescribe(exercise, sets: sets, ctx: ctx)
    }

    // MARK: Fitting the clock

    /// Bring a session inside the time budget without gutting it. In order: trim big exercises from 4 to 3 sets,
    /// trim accessories to 2 sets, shorten rests a little, drop accessories, trim compounds to 2 sets, and only
    /// then drop exercises.
    private static func fit(_ planned: inout [PlannedExercise], toSeconds budget: Int) {
        func total() -> Int { planned.reduce(0) { $0 + $1.totalSeconds } }
        let tolerance = 120
        var restCuts = 0
        var guardCount = 0
        while total() > budget + tolerance && guardCount < 80 {
            guardCount += 1
            if let i = planned.lastIndex(where: { $0.sets > 3 }) {
                planned[i].sets -= 1
                continue
            }
            if let i = planned.lastIndex(where: { !$0.exercise.isCompound && $0.sets > 2 }) {
                planned[i].sets -= 1
                continue
            }
            if restCuts < 2 {
                restCuts += 1
                for i in planned.indices {
                    let floor = planned[i].exercise.isCompound && planned[i].exercise.isLoaded ? 75 : 40
                    let cut = Int((Double(planned[i].restSeconds) * 0.85 / 5).rounded()) * 5
                    planned[i].restSeconds = max(min(planned[i].restSeconds, floor), cut)
                }
                continue
            }
            if planned.count > 3, let i = planned.lastIndex(where: { !$0.exercise.isCompound }) {
                planned.remove(at: i)
                continue
            }
            if let i = planned.lastIndex(where: { $0.sets > 2 }) {
                planned[i].sets -= 1
                continue
            }
            if planned.count > 3 {
                planned.removeLast()
                continue
            }
            break
        }
    }

    private static func addRampSets(_ planned: inout [PlannedExercise]) {
        guard let i = planned.firstIndex(where: { $0.exercise.isLoaded && $0.exercise.isCompound && $0.weightKg != nil }),
              let working = planned[i].weightKg else { return }
        let exercise = planned[i].exercise
        var plan: [(Double, Int)]
        if working >= 40 {
            plan = [(0.5, 8), (0.7, 5), (0.85, 2)]
        } else if working >= 20 {
            plan = [(0.5, 8), (0.75, 4)]
        } else if working >= 10 {
            plan = [(0.6, 6)]
        } else {
            plan = []
        }
        var ramp: [RampSet] = []
        for (fraction, reps) in plan {
            let load = Progression.roundLoad(working * fraction, for: exercise)
            if load < working && !ramp.contains(where: { $0.weightKg == load }) {
                ramp.append(RampSet(weightKg: load, reps: reps))
            }
        }
        planned[i].rampSets = ramp
    }

    // MARK: Warm-up

    static func warmupDrills(for exercises: [Exercise], profile: UserProfile) -> [PlannedExercise] {
        guard profile.sessionMinutes >= 20 else { return [] }
        let muscles = Set(exercises.map { $0.muscle })
        var wish: [String] = []
        if muscles.contains(.legs) { wish += ["worlds_greatest", "hip_flexor_stretch"] }
        if !muscles.isDisjoint(with: [.chest, .back, .shoulders, .arms]) { wish += ["shoulder_circles", "thoracic_rotation"] }
        wish += ["cat_cow", "worlds_greatest", "shoulder_circles", "hamstring_stretch"]

        var drills: [PlannedExercise] = []
        for id in wish where drills.count < 3 {
            let exercise = ExerciseLibrary.exercise(id)
            guard exercise.id == id, isAllowed(exercise, profile: profile),
                  !drills.contains(where: { $0.exerciseID == id }) else { continue }
            drills.append(PlannedExercise(exerciseID: id, sets: 1, target: 30, restSeconds: 10))
        }
        return drills
    }

    // MARK: Exercise selection

    static func isAllowed(_ exercise: Exercise, profile: UserProfile) -> Bool {
        // A pull-up bar is all the equipment a pull-up needs, so it works at home too (the library marks it as gym).
        let barIsEnough = ExerciseMetaTable.needsPullUpBar.contains(exercise.id) && profile.hasPullUpBar
        if exercise.equipment.rank > profile.equipment.rank && !barIsEnough { return false }
        if profile.excludedExercises.contains(exercise.id) { return false }
        let meta = exercise.meta
        if profile.lowImpactOnly && meta.isImpact { return false }
        if meta.stress.contains(where: { profile.limitations.contains($0) }) { return false }
        return true
    }

    /// The person's current rung on a ladder.
    static func rung(_ ladder: Ladder, profile: UserProfile) -> Int {
        if let stored = profile.rungs[ladder.rawValue] { return stored }
        return Assessment.place(history: profile.history, frequency: profile.frequency, check: profile.check).rung(ladder)
    }

    static func pick(
        _ pattern: Pattern,
        occurrence: Int,
        profile: UserProfile,
        blockNumber: Int,
        sessionIndex: Int = 0,
        used: Set<String>
    ) -> Exercise? {
        for candidate in [pattern] + pattern.fallbacks {
            if let exercise = pickExact(candidate, occurrence: occurrence, profile: profile, blockNumber: blockNumber, sessionIndex: sessionIndex, used: used) {
                return exercise
            }
        }
        return nil
    }

    private static func pickExact(
        _ pattern: Pattern,
        occurrence: Int,
        profile: UserProfile,
        blockNumber: Int,
        sessionIndex: Int,
        used: Set<String>
    ) -> Exercise? {
        let allowed = ExerciseLibrary.all.filter {
            $0.pattern == pattern && !used.contains($0.id) && isAllowed($0, profile: profile)
        }
        guard !allowed.isEmpty else { return nil }

        // Loaded options (best progression) come first, limited by level.
        var pool = allowed.filter { $0.isLoaded && $0.level.rank <= profile.level.rank }
        if pattern == .verticalPull, rung(.pull, profile: profile) >= 2,
           let pullup = allowed.first(where: { $0.id == "pullup" }) {
            pool.append(pullup)
        }

        if pool.isEmpty, let ladder = pattern.ladder {
            // Bodyweight ladder: the highest allowed rung at or below the person's current rung.
            let members = allowed.filter { $0.meta.ladder == ladder }
            let current = rung(ladder, profile: profile)
            let rungs = Set(members.map { $0.meta.rung }).sorted()
            // Never jump above the person's rung: if the easier variations are excluded, skip the slot.
            if let target = rungs.last(where: { $0 <= current }) {
                // The current rung leads; the rung just below is used for variety on other days.
                pool = members.filter { $0.meta.rung == target }
                    + members.filter { $0.meta.rung == target - 1 }
            }
        } else if pool.isEmpty {
            // Non-ladder bodyweight movements (calf raise, twists, cardio, mobility, ...).
            pool = allowed.filter { !$0.isLoaded && $0.meta.ladder == nil }
            if pool.isEmpty { pool = allowed.filter { $0.level.rank <= profile.level.rank } }
        }
        guard !pool.isEmpty else { return nil }

        pool.sort { a, b in
            if a.meta.ladder != nil, a.meta.ladder == b.meta.ladder, a.meta.rung != b.meta.rung {
                return a.meta.rung > b.meta.rung
            }
            if a.meta.priority != b.meta.priority { return a.meta.priority < b.meta.priority }
            return a.id < b.id
        }
        let top = Array(pool.prefix(3))
        let step = profile.level == .beginner ? 2 : 1
        // Variants change at block boundaries and differ by day of the week, so the same day always repeats
        // the same lifts within a block (progression stays measurable).
        var chosen = top[(blockNumber / step + occurrence + sessionIndex) % top.count]

        // Honour "I prefer this instead" from earlier swaps.
        if let replacementID = profile.swapPreferences[chosen.id],
           let replacement = allowed.first(where: { $0.id == replacementID }),
           preferenceFits(replacement, profile: profile) {
            chosen = replacement
        }
        return chosen
    }

    /// A remembered swap must still respect the person's level and rung (e.g. a beginner never gets a back squat
    /// from an old preference).
    private static func preferenceFits(_ exercise: Exercise, profile: UserProfile) -> Bool {
        if exercise.isLoaded && exercise.level.rank > profile.level.rank { return false }
        if let ladder = exercise.meta.ladder, !exercise.isLoaded, exercise.meta.rung > rung(ladder, profile: profile) { return false }
        return true
    }

    // MARK: Quick workouts

    static func quick(
        _ kind: QuickKind,
        profile: UserProfile,
        history: [WorkoutSession],
        now: Date = Date()
    ) -> Workout {
        var adjusted = profile
        if kind != .mobility { adjusted.equipment = .bodyweight }
        let blockNo = Periodization.blockNumber(on: now, profile: profile)
        let ctx = context(profile: adjusted, history: history, date: now, now: now, readiness: .normal, usePhase: false)

        let spec: (id: String, title: String, subtitle: String, theme: MuscleGroup, patterns: [Pattern], budget: Int, sets: Int, rest: Int?)
        switch kind {
        case .short:
            spec = ("quick-short", L("Short Workout"), L("10-minute no-equipment blast"), .cardio,
                    [.squat, .cardio, .horizontalPush, .coreStability, .cardio], 10, 2, 20)
        case .noEquipment:
            spec = ("quick-bodyweight", L("Wall Workouts"), L("Full body, zero equipment"), .fullBody,
                    [.squat, .horizontalPush, .horizontalPull, .hinge, .coreStability, .lunge, .verticalPush, .coreFlexion], profile.sessionMinutes, 3, nil)
        case .mobility:
            spec = ("quick-mobility", L("Mobility & Stretch"), L("Loosen up and recover"), .mobility,
                    [.mobility, .mobility, .mobility, .mobility, .mobility, .mobility], 10, 2, 10)
        }

        var used = Set<String>()
        var occurrences: [Pattern: Int] = [:]
        var planned: [PlannedExercise] = []
        for pattern in spec.patterns {
            let occurrence = occurrences[pattern, default: 0]
            guard let exercise = pick(pattern, occurrence: occurrence, profile: adjusted, blockNumber: blockNo, used: used) else { continue }
            occurrences[pattern] = occurrence + 1
            used.insert(exercise.id)
            var item = prescribe(exercise, sets: spec.sets, ctx: ctx)
            if let rest = spec.rest { item.restSeconds = rest }
            item.repsInReserve = nil
            planned.append(item)
        }
        // Very restricted people still get a few exercises, as in regular sessions.
        if planned.count < 3 {
            for pattern in [Pattern.coreStability, .coreFlexion, .cardio, .squat, .hinge, .mobility] where planned.count < 3 {
                guard let exercise = pick(pattern, occurrence: 0, profile: adjusted, blockNumber: blockNo, used: used) else { continue }
                used.insert(exercise.id)
                var item = prescribe(exercise, sets: spec.sets, ctx: ctx)
                if let rest = spec.rest { item.restSeconds = rest }
                item.repsInReserve = nil
                planned.append(item)
            }
        }
        fit(&planned, toSeconds: spec.budget * 60)
        return Workout(id: spec.id, title: spec.title, subtitle: spec.subtitle, theme: spec.theme, exercises: planned)
    }
}
