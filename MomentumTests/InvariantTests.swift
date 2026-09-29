import XCTest
@testable import Momentum

/// Property-style tests: thousands of random people, histories and dates, checking rules that must always hold.
/// The generator is seeded, so a failure reproduces; set `INVARIANT_SEED` / `INVARIANT_CASES` to explore further.
final class InvariantTests: EnglishTestCase {
    /// Small deterministic generator (SplitMix64).
    private struct Random {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() % UInt64(range.count)) }
        mutating func chance(_ p: Double) -> Bool { Double(next() % 10_000) / 10_000 < p }
        mutating func pick<T>(_ items: [T]) -> T { items[int(0...(items.count - 1))] }
    }

    private static var seed: UInt64 { UInt64(ProcessInfo.processInfo.environment["INVARIANT_SEED"] ?? "") ?? 20_260_929 }
    private static var cases: Int { Int(ProcessInfo.processInfo.environment["INVARIANT_CASES"] ?? "") ?? 40 }

    private func randomProfile(_ r: inout Random) -> UserProfile {
        var p = UserProfile()
        p.level = r.pick(FitnessLevel.allCases)
        p.goal = r.pick(Goal.allCases)
        p.equipment = r.pick(Equipment.allCases)
        p.sessionMinutes = r.pick([20, 30, 45, 60, 90])
        p.weightKg = Double(r.int(40...140))
        p.age = r.int(16...85)
        p.sex = r.pick(Sex.allCases)
        p.trainingWeekdays = Array(Set((0..<r.int(1...6)).map { _ in r.int(1...7) }))
        p.limitations = BodyArea.allCases.filter { _ in r.chance(0.25) }
        p.lowImpactOnly = r.chance(0.3)
        p.hasPullUpBar = r.chance(0.4)
        p.maxDumbbellKg = r.chance(0.5) ? Double(r.int(4...40)) : 0
        p.excludedExercises = ExerciseLibrary.all.filter { _ in r.chance(0.05) }.map(\.id)
        p.startDate = T.monday
        p.blockStart = T.monday
        p.onboarded = true
        p.rungs = Assessment.place(history: r.pick(TrainingHistory.allCases), frequency: r.pick(RecentFrequency.allCases), check: FitnessCheck()).rungs
        return p
    }

    /// Completes a plan the way a person would: mostly at target, sometimes short, sometimes well above.
    private func session(_ workout: Workout, on date: Date, _ r: inout Random) -> WorkoutSession {
        var logs: [ExerciseLog] = []
        var done = 0
        var planned = 0
        for item in workout.exercises {
            let exercise = item.exercise
            var sets: [SetLog] = []
            for _ in 0..<item.sets {
                planned += 1
                if r.chance(0.1) { continue }
                let value = max(1, item.target + r.int(-4...4))
                sets.append(SetLog(reps: exercise.kind == .timed ? 0 : value, weightKg: item.weightKg ?? 0, seconds: exercise.kind == .timed ? value : 0))
            }
            done += sets.count
            if !sets.isEmpty {
                logs.append(ExerciseLog(exerciseID: exercise.id, targetSets: item.sets, target: item.target, sets: sets,
                                        repMin: item.repMin, repMax: item.repMax, effort: r.pick([Effort.easy, .good, .hard])))
            }
        }
        return WorkoutSession(date: date, title: workout.title, durationSeconds: workout.minutes * 60, calories: 200,
                              plannedSets: planned, completedSets: done, logs: logs,
                              feedback: r.chance(0.7) ? r.pick(WorkoutFeedback.allCases) : nil, readiness: .normal, wasDeload: workout.phase?.isDeload)
    }

    private func check(_ workout: Workout, profile p: UserProfile, _ label: String) {
        var ids = Set<String>()
        for item in workout.exercises {
            let e = item.exercise
            XCTAssertTrue(ids.insert(item.exerciseID).inserted, "\(label): duplicate \(e.id)")
            XCTAssertTrue((2...5).contains(item.sets) || e.muscle == .mobility, "\(label): \(e.id) has \(item.sets) sets")
            XCTAssertTrue(PlanGenerator.isAllowed(e, profile: p), "\(label): \(e.id) not allowed for this person")
            XCTAssertLessThanOrEqual(item.repMin, item.target, "\(label): \(e.id)")
            XCTAssertLessThanOrEqual(item.target, item.repMax, "\(label): \(e.id)")
            XCTAssertGreaterThanOrEqual(item.restSeconds, 10, "\(label): \(e.id) rest")
            if e.isLoaded {
                let kg = item.weightKg ?? 0
                XCTAssertTrue(kg.isFinite && kg > 0, "\(label): \(e.id) load \(kg)")
                if let cap = Progression.dumbbellCap(for: e, profile: p) {
                    XCTAssertLessThanOrEqual(kg, cap + 0.0001, "\(label): \(e.id) above the dumbbell cap")
                }
            } else {
                XCTAssertNil(item.weightKg, "\(label): \(e.id) has a weight")
            }
            XCTAssertFalse((item.reason ?? "").contains("{"), "\(label): unresolved placeholder")
        }
        XCTAssertFalse(workout.id.isEmpty)
    }

    func testRandomPeopleGetSafeWellFormedPlansThatAdaptWithoutBreakingRules() {
        var r = Random(state: Self.seed)
        for index in 0..<Self.cases {
            var p = randomProfile(&r)
            let label = "seed \(Self.seed) case \(index)"
            var history: [WorkoutSession] = []
            var lastRungs = p.rungs

            // Twelve weeks: plan each scheduled day, do it imperfectly, adapt.
            for day in 0..<84 {
                let date = T.day(day)
                let now = date
                guard let workout = PlanGenerator.workout(on: date, profile: p, history: history, now: now) else { continue }
                check(workout, profile: p, label + " day \(day)")

                // Same inputs, same plan.
                let again = PlanGenerator.workout(on: date, profile: p, history: history, now: now)
                XCTAssertEqual(again?.exercises, workout.exercises, "\(label) day \(day): not deterministic")

                if r.chance(0.15) { continue }                       // a missed session
                let done = session(workout, on: date, &r)
                history.append(done)
                let outcome = AdaptiveEngine.apply(session: done, to: p, history: history, previousSessionDate: history.dropLast().last?.date)
                p = outcome.profile
                XCTAssertTrue((-3...3).contains(p.intensity), "\(label) day \(day): intensity \(p.intensity)")
                for (ladder, rung) in p.rungs {
                    let max = Ladder(rawValue: ladder).map(ExerciseMetaTable.maxRung) ?? 0
                    XCTAssertTrue((0...max).contains(rung), "\(label) day \(day): \(ladder) rung \(rung)")
                    // A ladder moves one rung at a time.
                    XCTAssertLessThanOrEqual(abs(rung - (lastRungs[ladder] ?? rung)), 1, "\(label) day \(day): \(ladder) jumped")
                }
                lastRungs = p.rungs
                XCTAssertTrue(outcome.messages.allSatisfy { !$0.contains("{") }, "\(label): unresolved placeholder in a message")
            }
        }
    }

    func testEverySwapSuggestionRespectsTheRules() {
        var r = Random(state: Self.seed &+ 1)
        for index in 0..<Self.cases {
            let p = randomProfile(&r)
            let day = T.day(r.int(0...20))
            guard let workout = PlanGenerator.workout(on: day, profile: p, history: [], now: day),
                  !workout.exercises.isEmpty else { continue }
            let planned = r.pick(workout.exercises)
            let pain = BodyArea.allCases.filter { _ in r.chance(0.3) }
            for reason in SwapReason.allCases {
                let out = Alternatives.suggest(for: planned, in: workout, reason: reason, profile: p, painAreas: pain)
                XCTAssertLessThanOrEqual(out.count, 6)
                for suggestion in out {
                    let e = suggestion.exercise
                    let label = "seed \(Self.seed) case \(index) \(reason) \(planned.exerciseID) -> \(e.id)"
                    XCTAssertTrue(PlanGenerator.isAllowed(e, profile: p), label)
                    XCTAssertNotEqual(e.id, planned.exerciseID, label)
                    XCTAssertFalse(workout.exercises.contains { $0.exerciseID == e.id }, "\(label): already in the workout")
                    XCTAssertFalse(suggestion.why.isEmpty, label)
                    if reason == .tooHard { XCTAssertNotEqual(suggestion.relation, .harder, label) }
                    if reason == .tooEasy { XCTAssertNotEqual(suggestion.relation, .easier, label) }
                    if e.isLoaded { XCTAssertLessThanOrEqual(e.level.rank, p.level.rank, "\(label): above the person's level") }
                    if reason == .pain, !pain.isEmpty {
                        XCTAssertFalse(e.meta.stress.contains { pain.contains($0) }, "\(label): stresses the painful area")
                    }
                }
            }
        }
    }
}
