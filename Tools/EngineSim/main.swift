import Foundation
@testable import Momentum

// Prints the plans the engine builds for a few different people, so they can be reviewed by eye.
// Run: swift run EngineSim plans

func persona(_ name: String, _ configure: (inout UserProfile) -> Void) -> (String, UserProfile) {
    var p = UserProfile()
    p.name = name
    p.onboarded = true
    configure(&p)
    let placement = Assessment.place(p)
    p.level = placement.level
    p.rungs = placement.rungs
    return (name, p)
}

func monday(_ offsetWeeks: Int = 0) -> Date {
    var c = Calendar.current
    c.firstWeekday = 2
    let base = c.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9))!
    return c.date(byAdding: .day, value: 7 * offsetWeeks, to: base)!
}

func describe(_ w: Workout, units: UnitSystem = .metric) -> String {
    var lines: [String] = []
    let phase = w.phase.map { " [\($0.label), \($0.repsInReserve) RIR]" } ?? ""
    lines.append("  \(w.title) (\(w.subtitle)) ~\(w.minutes) min, \(w.totalSets) sets\(phase)")
    if let note = w.note { lines.append("    note: \(note)") }
    if !w.warmup.isEmpty {
        lines.append("    warm-up: " + w.warmup.map { $0.exercise.name }.joined(separator: ", "))
    }
    for p in w.exercises {
        let e = p.exercise
        var load = p.weightKg.map { " @ \(units.formatWeight($0))" } ?? ""
        if !p.rampSets.isEmpty {
            load += "  (ramp " + p.rampSets.map { "\(units.formatWeight($0.weightKg))x\($0.reps)" }.joined(separator: ", ") + ")"
        }
        lines.append("    \(e.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(p.targetLabel)\(load)  rest \(p.restSeconds)s")
    }
    return lines.joined(separator: "\n")
}

func printWeek(_ p: UserProfile, weekOffset: Int = 0) {
    let day = monday(weekOffset)
    let week = PlanGenerator.week(containing: day, profile: p, history: [], now: monday(0))
    let planned = PlanGenerator.plannedSets(in: week)
    for item in week { print(describe(item.workout)) }
    let targets = VolumePlanner.weeklyTargets(for: p)
    var parts: [String] = []
    for m in VolumePlanner.muscles {
        let t = targets[m]!
        parts.append("\(m.title) \(planned[m] ?? 0)/\(t.low)-\(t.high)")
    }
    print("  weekly sets vs target: " + parts.joined(separator: " | "))
}

let personas: [(String, UserProfile)] = [
    persona("A: beginner, no equipment, lose fat, knees, 3 days/30 min") { p in
        p.goal = .loseFat; p.equipment = .bodyweight; p.sessionMinutes = 30
        p.trainingWeekdays = [2, 4, 6]; p.limitations = [.knees]; p.lowImpactOnly = true
        p.sex = .female; p.weightKg = 78; p.age = 41
    },
    persona("B: intermediate, dumbbells (max 24 kg), build muscle, 4 days/45 min") { p in
        p.goal = .buildMuscle; p.equipment = .dumbbells; p.sessionMinutes = 45; p.maxDumbbellKg = 24
        p.trainingWeekdays = [2, 3, 5, 6]; p.history = .sixTo24Months; p.frequency = .threeToFour
        p.sex = .male; p.weightKg = 80; p.age = 29
        p.check = FitnessCheck(pushups: 20, squats: 35, plankSeconds: 60, pullups: 0)
    },
    persona("C: advanced, full gym, get stronger, 5 days/60 min") { p in
        p.goal = .getStronger; p.equipment = .fullGym; p.sessionMinutes = 60
        p.trainingWeekdays = [2, 3, 4, 6, 7]; p.history = .over2Years; p.frequency = .fivePlus
        p.sex = .male; p.weightKg = 90; p.age = 32
        p.check = FitnessCheck(pushups: 40, squats: 60, plankSeconds: 100, pullups: 10)
    },
    persona("D: older beginner, no equipment, general fitness, 2 days/30 min, shoulders") { p in
        p.goal = .stayFit; p.equipment = .bodyweight; p.sessionMinutes = 30
        p.trainingWeekdays = [3, 6]; p.limitations = [.shoulders]
        p.sex = .female; p.weightKg = 68; p.age = 61
    }
]

let mode = CommandLine.arguments.dropFirst().first ?? "plans"
if mode == "plans" {
    for (name, p) in personas {
        print("\n=== \(name)  -> level \(p.level.title), rungs \(p.rungs.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
        printWeek(p)
    }
}

// MARK: - Longitudinal simulation

struct SeededRandom {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 33) & 0xFFFFFF) / Double(0xFFFFFF)
    }
}

/// A synthetic person: real strength that grows, never known to the engine except through logged sets.
struct Athlete {
    var e1rm: [String: Double] = [:]      // loaded lifts (kg)
    var bodyweightMax: [String: Double] = [:]   // reps or seconds to failure at current fitness
    var weeklyGain: Double
    var rng: SeededRandom

    mutating func strength(of exercise: Exercise, profile: UserProfile) -> Double {
        if let existing = e1rm[exercise.id] { return existing }
        // True strength is ~15% above what the engine's first guess assumes, with per-lift variation.
        let guess = Progression.initialLoad(for: exercise, profile: profile) ?? 0
        let noise = 0.9 + 0.2 * rng.next()
        let value = max(1, guess / 0.85 * 1.15 * noise) * (1 + 15.0 / 30)   // guess is a ~10-rep working weight
        e1rm[exercise.id] = value
        return value
    }

    mutating func capacityBW(of exercise: Exercise, level: FitnessLevel) -> Double {
        if let existing = bodyweightMax[exercise.id] { return existing }
        let rung = Double(exercise.meta.rung)
        let timed = exercise.kind == .timed
        let base = timed ? 35.0 : 16.0
        let value = max(timed ? 15 : 6, base - 4 * rung + Double(level.rank) * 3) * (0.85 + 0.3 * rng.next())
        bodyweightMax[exercise.id] = value
        return value
    }

    mutating func grow(weeks: Double = 1, factor: Double = 1) {
        for key in e1rm.keys { e1rm[key] = e1rm[key]! * (1 + weeklyGain * weeks * factor) }
        for key in bodyweightMax.keys { bodyweightMax[key] = bodyweightMax[key]! * (1 + weeklyGain * 0.8 * weeks * factor) }
    }
}

struct SimResult {
    var session: WorkoutSession
    var workout: Workout
}

func performSession(_ workout: Workout, on date: Date, athlete: inout Athlete, profile: UserProfile,
                    readiness: Readiness = .normal) -> WorkoutSession {
    var logs: [ExerciseLog] = []
    var planned = 0, done = 0
    var failedSets = 0, totalSets = 0, easyExercises = 0
    for p in workout.exercises {
        let e = p.exercise
        var sets: [SetLog] = []
        var minMargin = 99.0
        for i in 0..<p.sets {
            planned += 1
            var cap: Double
            var load = 0.0
            if e.isLoaded {
                load = p.weightKg ?? 0
                let strength = athlete.strength(of: e, profile: profile)
                cap = load > 0 ? 30 * (strength / load - 1) : 30
            } else {
                cap = athlete.capacityBW(of: e, level: profile.level)
            }
            cap -= 0.7 * Double(i)                      // fatigue across sets
            let noise = (athlete.rng.next() - 0.5) * 1.6
            let rir = Double(p.repsInReserve ?? 1)
            let effort = max(0, floor(cap + noise - min(rir, 2)))   // people stop a little short of failure
            let value = Int(min(Double(p.repMax), effort))
            minMargin = min(minMargin, cap - Double(value))
            done += 1
            totalSets += 1
            if value < p.repMin { failedSets += 1 }
            sets.append(SetLog(reps: e.kind == .timed ? 0 : value, weightKg: load, seconds: e.kind == .timed ? value : 0))
        }
        let effort: Effort = minMargin >= 4 ? .easy : (minMargin <= 1.2 ? .hard : .good)
        if effort == .easy { easyExercises += 1 }
        logs.append(ExerciseLog(exerciseID: e.id, targetSets: p.sets, target: p.target, sets: sets,
                                repMin: p.repMin, repMax: p.repMax, effort: effort))
    }
    let feedback: WorkoutFeedback
    if Double(failedSets) / Double(max(1, totalSets)) > 0.3 { feedback = .tooHard }
    else if easyExercises * 2 > workout.exercises.count { feedback = .tooEasy }
    else { feedback = .justRight }
    return WorkoutSession(date: date, title: workout.title, durationSeconds: workout.minutes * 60, calories: 250,
                          plannedSets: planned, completedSets: done, logs: logs, feedback: feedback,
                          readiness: readiness, wasDeload: workout.phase?.isDeload)
}

var verbose = CommandLine.arguments.contains("-v")

func simulate(_ name: String, profile start: UserProfile, weeks: Int, weeklyGain: Double,
              skipWeeks: ClosedRange<Int>? = nil, track: [String]) {
    print("\n=== SIM \(name)")
    var profile = start
    profile.startDate = monday(0)
    profile.blockStart = monday(0)
    var history: [WorkoutSession] = []
    var athlete = Athlete(weeklyGain: weeklyGain, rng: SeededRandom(state: 42))
    let cal = PlanGenerator.calendar
    var lines: [String] = []
    var levelSeen = profile.level
    for week in 0..<weeks {
        let weekStartDate = monday(week)
        var trained = 0
        var phaseLabel = ""
        var trackedNow: [String] = []
        var notes: [String] = []
        if let skip = skipWeeks, skip.contains(week) { lines.append(String(format: "w%02d  (no training)", week + 1)); athlete.grow(factor: 0.0); continue }
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStartDate),
                  let workout = PlanGenerator.workout(on: day, profile: profile, history: history, now: day) else { continue }
            phaseLabel = workout.phase.map { $0.isDeload ? "DELOAD" : "build\($0.weekInBlock + 1)" } ?? ""
            let prev = history.map { $0.date }.max()
            let session = performSession(workout, on: day, athlete: &athlete, profile: profile)
            history.append(session)
            let out = AdaptiveEngine.apply(session: session, to: profile, history: history, previousSessionDate: prev)
            profile = out.profile
            trained += 1
            notes += out.messages
            for id in track {
                if let p = workout.exercises.first(where: { $0.exerciseID == id }) {
                    let e = p.exercise
                    let load = p.weightKg.map { profile.units.formatWeight($0) } ?? ""
                    let log = session.logs.first(where: { $0.exerciseID == id })
                    let reps = log.map { $0.sets.map { String($0.reps + $0.seconds) }.joined(separator: "/") } ?? ""
                    trackedNow.append("\(e.name.prefix(14)) \(p.sets)x \(load) [\(reps)]" + (verbose ? " <\(p.reason ?? "")>" : ""))
                }
            }
        }
        if profile.level != levelSeen { notes.append("LEVEL -> \(profile.level.title)"); levelSeen = profile.level }
        athlete.grow()
        lines.append(String(format: "w%02d %-7@ sessions:%d  ", week + 1, phaseLabel as NSString, trained) + trackedNow.joined(separator: " | "))
        for n in Set(notes) { lines.append("      • \(n)") }
    }
    print(lines.joined(separator: "\n"))
    print("  final: level \(profile.level.title), intensity \(profile.intensity), rungs " + profile.rungs.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
}

if mode == "sim" {
    simulate("B intermediate DB (max 24 kg), 3-week break after week 9", profile: personas[1].1, weeks: 16, weeklyGain: 0.012,
             skipWeeks: 9...11, track: ["db_bench", "goblet_squat"])
    simulate("A beginner bodyweight (knees)", profile: personas[0].1, weeks: 16, weeklyGain: 0.03,
             track: ["wall_pushup", "knee_pushup", "pushup", "bw_squat", "plank", "dead_bug"])
    simulate("C advanced gym", profile: personas[2].1, weeks: 12, weeklyGain: 0.006,
             track: ["bench_press", "back_squat"])
}

if mode == "alts" {
    for (name, p) in personas {
        print("\n=== \(name)")
        guard let w = PlanGenerator.week(containing: monday(0), profile: p, history: [], now: monday(0)).first?.workout else { continue }
        for planned in w.exercises.prefix(4) {
            print("  \(planned.exercise.name)")
            for reason in SwapReason.allCases {
                let alts = Alternatives.suggest(for: planned, in: w, reason: reason, profile: p)
                print("    \(reason.title): " + (alts.isEmpty ? "(none)" : alts.map { "\($0.exercise.name) [\($0.relation.title)]" }.joined(separator: ", ")))
            }
        }
    }
}

// MARK: - JSON for the app-screen mockups (tools/mockups)

func weekdayName(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEEE"
    return f.string(from: date)
}

if mode == "mock" {
    var p = personas[1].1
    p.name = "Alex"
    p.startDate = monday(0)
    p.blockStart = monday(0)
    let units = p.units
    var history: [WorkoutSession] = []
    var athlete = Athlete(weeklyGain: 0.012, rng: SeededRandom(state: 7))
    let cal = PlanGenerator.calendar
    // Two weeks of training so the plan has real history to react to.
    for week in 0..<2 {
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: monday(week)),
                  let workout = PlanGenerator.workout(on: day, profile: p, history: history, now: day) else { continue }
            let prev = history.map { $0.date }.max()
            let session = performSession(workout, on: day, athlete: &athlete, profile: p)
            history.append(session)
            p = AdaptiveEngine.apply(session: session, to: p, history: history, previousSessionDate: prev).profile
        }
        athlete.grow()
    }
    let today = monday(2)
    let workout = PlanGenerator.workout(on: today, profile: p, history: history, now: today)!

    func encode(_ w: Workout) -> [String: Any] {
        func item(_ e: PlannedExercise) -> [String: Any] {
            var d: [String: Any] = [
                "id": e.exerciseID, "name": e.exercise.name, "muscle": e.exercise.muscle.rawValue,
                "sets": e.sets, "target": e.target, "repMin": e.repMin, "repMax": e.repMax, "rest": e.restSeconds,
                "timed": e.exercise.kind == .timed, "label": e.targetLabel
            ]
            if let kg = e.weightKg { d["weight"] = units.formatWeight(kg) }
            if let r = e.reason { d["reason"] = r }
            if let rir = e.repsInReserve { d["rir"] = rir }
            d["ramp"] = e.rampSets.map { "\(units.formatWeight($0.weightKg)) × \($0.reps)" }
            return d
        }
        return [
            "title": w.title, "subtitle": w.subtitle, "minutes": w.minutes, "sets": w.totalSets,
            "calories": w.calories(weightKg: p.weightKg),
            "phase": w.phase.map { ["label": $0.label, "rir": $0.repsInReserve, "deload": $0.isDeload] } as Any,
            "warmup": w.warmup.map { $0.exercise.name },
            "exercises": w.exercises.map(item)
        ]
    }

    let week = PlanGenerator.week(containing: today, profile: p, history: history, now: today)
    let planned = PlanGenerator.plannedSets(in: week)
    let targets = VolumePlanner.weeklyTargets(for: p)
    let target = workout.exercises[0]
    var alts: [String: Any] = [:]
    for reason in SwapReason.allCases {
        let list = Alternatives.suggest(for: target, in: workout, reason: reason, profile: p, painAreas: reason == .pain ? [.shoulders] : [], limit: 4)
        alts[reason.rawValue] = list.map { ["id": $0.exercise.id, "name": $0.exercise.name, "relation": $0.relation.title, "why": $0.why] }
    }
    let placement = Assessment.place(personas[1].1)
    let json: [String: Any] = [
        "name": p.name, "level": p.level.title, "placementNotes": placement.notes,
        "week": week.map { ["day": weekdayName($0.date), "title": $0.workout.title, "minutes": $0.workout.minutes] },
        "volume": VolumePlanner.muscles.map { ["muscle": $0.title, "planned": planned[$0] ?? 0, "low": targets[$0]!.low, "high": targets[$0]!.high] },
        "workout": encode(workout),
        "swapExercise": ["id": target.exerciseID, "name": target.exercise.name],
        "alternatives": alts,
        "blockLength": Periodization.blockLength(for: p.level)
    ]
    let data = try! JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    print(String(data: data, encoding: .utf8)!)
}
