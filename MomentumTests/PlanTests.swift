import XCTest
@testable import Momentum

final class PlanGeneratorTests: XCTestCase {
    private func week(_ p: UserProfile, _ n: Int = 0, history: [WorkoutSession] = []) -> [(date: Date, workout: Workout)] {
        PlanGenerator.week(containing: T.week(n), profile: p, history: history, now: T.week(n))
    }

    // MARK: Schedule

    func testTrainingDaysAreTheChosenWeekdays() {
        let p = T.profile(weekdays: [3, 5, 7])       // Tue, Thu, Sat
        let days = week(p).map { Calendar.current.component(.weekday, from: $0.date) }
        XCTAssertEqual(days, [3, 5, 7])
    }

    func testSplitMatchesTheNumberOfDays() {
        XCTAssertEqual(PlanGenerator.split(for: T.profile(weekdays: [2])), [.fullBodyA])
        XCTAssertEqual(PlanGenerator.split(for: T.profile(weekdays: [2, 5])), [.fullBodyA, .fullBodyB])
        XCTAssertEqual(PlanGenerator.split(for: T.profile(level: .advanced, weekdays: [2, 4, 6])), [.push, .pull, .legs])
        XCTAssertEqual(PlanGenerator.split(for: T.profile(weekdays: [2, 3, 5, 6])), [.upperA, .lowerA, .upperB, .lowerB])
        XCTAssertEqual(PlanGenerator.split(for: T.profile(weekdays: [2, 3, 4, 6, 7])).count, 5)
        XCTAssertEqual(PlanGenerator.split(for: T.profile(weekdays: [2, 3, 4, 5, 6, 7])).count, 6)
    }

    func testSundayIsTheLastDayOfTheWeek() {
        let p = T.profile(weekdays: [1, 2, 4])       // Sun, Mon, Wed
        XCTAssertEqual(PlanGenerator.weekdays(for: p), [2, 4, 1])
    }

    func testNoWeekdaysFallsBackToAThreeDayDefault() {
        var p = T.profile()
        p.trainingWeekdays = []
        XCTAssertEqual(week(p).count, 3)
    }

    // MARK: Invariants over a broad grid

    func testEveryProfileGetsAValidPlan() {
        let weekdaySets: [[Int]] = [[2], [2, 5], [2, 4, 6], [2, 3, 5, 6], [2, 3, 4, 6, 7], [2, 3, 4, 5, 6, 7]]
        let areaSets: [[BodyArea]] = [[], [.knees], [.lowerBack, .shoulders], [.wrists, .knees, .shoulders, .lowerBack]]
        for level in FitnessLevel.allCases {
            for equipment in Equipment.allCases {
                for goal in Goal.allCases {
                    for days in weekdaySets {
                        for areas in areaSets {
                            for lowImpact in [false, true] {
                                let p = T.profile(level: level, goal: goal, equipment: equipment, weekdays: days,
                                                  minutes: 40, limitations: areas, lowImpact: lowImpact)
                                for (_, w) in week(p, 1) {
                                    let label = "\(level) \(equipment) \(goal) \(days.count)d \(areas) low:\(lowImpact) \(w.title)"
                                    let ids = w.exercises.map { $0.exerciseID }
                                    XCTAssertEqual(ids.count, Set(ids).count, "duplicate: \(label)")
                                    XCTAssertGreaterThanOrEqual(w.exercises.count, 3, label)
                                    for planned in w.exercises + w.warmup {
                                        let e = planned.exercise
                                        XCTAssertLessThanOrEqual(e.equipment.rank, equipment.rank, "equipment \(e.id): \(label)")
                                        XCTAssertTrue(e.meta.stress.allSatisfy { !areas.contains($0) }, "stress \(e.id): \(label)")
                                        if lowImpact { XCTAssertFalse(e.meta.isImpact, "impact \(e.id): \(label)") }
                                        XCTAssertGreaterThanOrEqual(planned.sets, 1, label)
                                        XCTAssertGreaterThan(planned.target, 0, label)
                                        XCTAssertLessThanOrEqual(planned.repMin, planned.repMax, label)
                                        XCTAssertGreaterThanOrEqual(planned.restSeconds, 10, label)
                                    }
                                    XCTAssertTrue(w.exercises.allSatisfy { $0.sets >= 2 && $0.sets <= 5 }, "sets: \(label)")
                                    // Never more than a two-minute overrun.
                                    XCTAssertLessThanOrEqual(w.totalSeconds, 40 * 60 + 150, "time: \(label) \(w.minutes)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func testWeeklyVolumeLandsInsideTheTargetForUnrestrictedPeople() {
        for level in FitnessLevel.allCases {
            for goal in Goal.allCases {
                let p = T.profile(level: level, goal: goal, equipment: .fullGym, weekdays: [2, 3, 5, 6], minutes: 75)
                let planned = PlanGenerator.plannedSets(in: week(p))
                for muscle in VolumePlanner.muscles {
                    let t = VolumePlanner.target(for: muscle, level: level, goal: goal)
                    let got = planned[muscle] ?? 0
                    XCTAssertGreaterThanOrEqual(got, t.low - 2, "\(level) \(goal) \(muscle): \(got) vs \(t)")
                    XCTAssertLessThanOrEqual(got, t.high + 3, "\(level) \(goal) \(muscle): \(got) vs \(t)")
                }
            }
        }
    }

    func testAdvancedTrainsMoreThanBeginnersWithTheSameTime() {
        let b = PlanGenerator.plannedSets(in: week(T.profile(level: .beginner, equipment: .fullGym, weekdays: [2, 3, 5, 6], minutes: 75)))
        let a = PlanGenerator.plannedSets(in: week(T.profile(level: .advanced, equipment: .fullGym, weekdays: [2, 3, 5, 6], minutes: 75)))
        XCTAssertGreaterThan(a.values.reduce(0, +), b.values.reduce(0, +))
    }

    func testPlansAreDeterministic() {
        let p = T.profile()
        let a = week(p).map { $0.workout.exercises.map { "\($0.exerciseID)-\($0.sets)-\($0.target)-\($0.weightKg ?? 0)" } }
        let b = week(p).map { $0.workout.exercises.map { "\($0.exerciseID)-\($0.sets)-\($0.target)-\($0.weightKg ?? 0)" } }
        XCTAssertEqual(a, b)
    }

    // MARK: Stability and variety

    func testTheSameDayRepeatsTheSameLiftsWithinABlock() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let ids = (0..<Periodization.blockLength(for: .intermediate)).map { n in
            week(p, n).first!.workout.exercises.map { $0.exerciseID }
        }
        for later in ids.dropFirst() { XCTAssertEqual(later, ids[0]) }
    }

    func testAccessoryVarietyChangesAcrossBlocks() {
        let p = T.profile(level: .intermediate, equipment: .fullGym, weekdays: [2, 3, 5, 6])
        let length = Periodization.blockLength(for: .intermediate)
        var seen = Set<String>()
        for block in 0..<4 {
            for item in week(p, block * length) { seen.formUnion(item.workout.exercises.map { $0.exerciseID }) }
        }
        var single = Set<String>()
        for item in week(p, 0) { single.formUnion(item.workout.exercises.map { $0.exerciseID }) }
        XCTAssertGreaterThan(seen.count, single.count)
    }

    func testDifferentDaysUseDifferentVariantsOfTheSameCoreRung() {
        let p = T.profile(level: .advanced, equipment: .fullGym, weekdays: [2, 3, 4, 6, 7])
        let cores = week(p).compactMap { item in item.workout.exercises.first { $0.exercise.pattern == .coreStability || $0.exercise.pattern == .coreFlexion }?.exerciseID }
        XCTAssertGreaterThan(Set(cores).count, 1)
    }

    // MARK: Prescription details

    func testWarmupHasThreeAllowedDrills() {
        let p = T.profile(minutes: 45)
        for item in week(p) {
            XCTAssertEqual(item.workout.warmup.count, 3)
            XCTAssertTrue(item.workout.warmup.allSatisfy { $0.exercise.muscle == .mobility })
        }
    }

    func testWarmupDrillsRespectWristLimits() {
        let p = T.profile(minutes: 45, limitations: [.wrists])
        for item in week(p) {
            XCTAssertFalse(item.workout.warmup.contains { $0.exerciseID == "cat_cow" || $0.exerciseID == "thoracic_rotation" })
        }
    }

    func testShortSessionsSkipTheWarmup() {
        XCTAssertTrue(week(T.profile(minutes: 15)).allSatisfy { $0.workout.warmup.isEmpty })
    }

    func testRampSetsAreLighterThanTheWorkingWeightAndOnlyOnTheFirstHeavyLift() {
        let p = T.profile(level: .advanced, equipment: .fullGym, weekdays: [2, 3, 5, 6], minutes: 75)
        for item in week(p) {
            let withRamp = item.workout.exercises.filter { !$0.rampSets.isEmpty }
            XCTAssertLessThanOrEqual(withRamp.count, 1)
            for planned in withRamp {
                XCTAssertTrue(planned.exercise.isLoaded && planned.exercise.isCompound)
                XCTAssertTrue(planned.rampSets.allSatisfy { $0.weightKg < planned.weightKg! })
                XCTAssertEqual(planned.rampSets.map { $0.weightKg }, planned.rampSets.map { $0.weightKg }.sorted())
            }
        }
    }

    func testHeaviestDumbbellIsRespected() {
        let p = T.profile(level: .advanced, equipment: .dumbbells, maxDumbbell: 14, weight: 100)
        for item in week(p) {
            for planned in item.workout.exercises where planned.exercise.equipment == .dumbbells {
                XCTAssertLessThanOrEqual(planned.weightKg ?? 0, 14)
            }
        }
    }

    func testBodyweightPlansNeverPrescribeWeights() {
        let p = T.profile(level: .beginner, equipment: .bodyweight)
        for item in week(p) { XCTAssertTrue(item.workout.exercises.allSatisfy { $0.weightKg == nil }) }
    }

    func testFatLossPlansAddACardioFinisherAndShorterRest() {
        let loseFat = T.profile(goal: .loseFat, equipment: .bodyweight)
        let build = T.profile(goal: .buildMuscle, equipment: .bodyweight)
        let lf = week(loseFat).first!.workout
        XCTAssertTrue(lf.exercises.contains { $0.exercise.muscle == .cardio })
        XCTAssertFalse(week(build).first!.workout.exercises.contains { $0.exercise.muscle == .cardio })
        let restLF = lf.exercises.filter { $0.exercise.muscle != .cardio }.map { $0.restSeconds }.max() ?? 0
        let restBM = week(build).first!.workout.exercises.map { $0.restSeconds }.max() ?? 0
        XCTAssertLessThan(restLF, restBM + 1)
    }

    func testOlderPeopleGetLongerRestAndAnExtraRepInReserve() {
        let young = week(T.profile(minutes: 120, age: 30)).first!.workout
        let older = week(T.profile(minutes: 120, age: 60)).first!.workout
        XCTAssertGreaterThan(older.exercises[0].restSeconds, young.exercises[0].restSeconds)
        XCTAssertEqual(older.exercises[0].repsInReserve, (young.exercises[0].repsInReserve ?? 0) + 1)
    }

    func testTimeBudgetLeavesRoomForTheWarmup() {
        let p = T.profile(minutes: 30)
        for item in week(p) { XCTAssertLessThanOrEqual(item.workout.minutes, 33) }
    }

    // MARK: Adaptation in the plan

    private func benchHistory(daysAgo: Int, load: Double = 20, reps: Int = 10) -> [WorkoutSession] {
        // An earlier, completed session so the plan has something to build on.
        [T.session(on: T.day(-daysAgo), logs: [T.log("db_bench", sets: Array(repeating: (reps, load), count: 3), min: 6, max: 10)])]
    }

    func testDeloadWeekHasFewerSetsAndLighterLoads() {
        let p = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        let length = Periodization.blockLength(for: .intermediate)
        let history = [T.session(on: T.week(length - 1).addingTimeInterval(-86_400), logs: [T.log("db_bench", sets: Array(repeating: (10, 20.0), count: 3), min: 6, max: 10)])]
        let normal = PlanGenerator.workout(on: T.week(length - 2), profile: p, history: history, now: T.week(length - 2))!
        let deload = PlanGenerator.workout(on: T.week(length - 1), profile: p, history: history, now: T.week(length - 1))!
        XCTAssertTrue(deload.phase!.isDeload)
        XCTAssertLessThan(deload.totalSets, normal.totalSets)
        let benchNormal = normal.exercises.first { $0.exerciseID == "db_bench" }
        let benchDeload = deload.exercises.first { $0.exerciseID == "db_bench" }
        if let n = benchNormal?.weightKg, let d = benchDeload?.weightKg { XCTAssertLessThan(d, n) }
        XCTAssertNotNil(deload.note)
    }

    func testComebackEasesTheLoadPerExercise() {
        let p = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        let old = benchHistory(daysAgo: 30)
        let now = T.day(0)
        let workout = PlanGenerator.workout(on: now, profile: p, history: old, now: now)!
        guard let bench = workout.exercises.first(where: { $0.exerciseID == "db_bench" }) else { return }
        XCTAssertLessThan(bench.weightKg ?? 99, 22)          // it would be 22 kg without the break
        XCTAssertTrue(bench.reason?.contains("Comeback") == true)
        XCTAssertNotNil(workout.note)
    }

    func testLowReadinessRemovesASetAndBlocksWeightJumps() {
        let p = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        let history = benchHistory(daysAgo: 3)
        let normal = PlanGenerator.workout(on: T.day(0), profile: p, history: history, now: T.day(0), readiness: .normal)!
        let tired = PlanGenerator.workout(on: T.day(0), profile: p, history: history, now: T.day(0), readiness: .low)!
        XCTAssertLessThan(tired.totalSets, normal.totalSets)
        if let n = normal.exercises.first(where: { $0.exerciseID == "db_bench" })?.weightKg,
           let t = tired.exercises.first(where: { $0.exerciseID == "db_bench" })?.weightKg {
            XCTAssertLessThanOrEqual(t, n)
            XCTAssertEqual(t, 20)
        }
        XCTAssertNotNil(tired.note)
    }

    func testLoadFollowsLoggedProgress() {
        let p = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        let before = PlanGenerator.workout(on: T.day(0), profile: p, history: benchHistory(daysAgo: 3, load: 20, reps: 10), now: T.day(0))!
        guard let bench = before.exercises.first(where: { $0.exerciseID == "db_bench" }) else { return XCTFail("no bench") }
        XCTAssertEqual(bench.weightKg, 22)
        XCTAssertEqual(bench.target, bench.repMin)
    }

    func testPositiveDifficultyOffsetAddsSetsAndNegativeRemovesThem() {
        var p = T.profile(level: .intermediate, equipment: .fullGym, weekdays: [2, 4, 6], minutes: 90)
        let base = week(p).first!.workout.totalSets
        p.intensity = 2
        XCTAssertGreaterThan(week(p).first!.workout.totalSets, base)
        p.intensity = -2
        XCTAssertLessThan(week(p).first!.workout.totalSets, base)
    }

    func testRungDeterminesTheBodyweightVariation() {
        var p = T.profile(level: .beginner, equipment: .bodyweight, weekdays: [2, 4, 6])
        p.rungs[Ladder.push.rawValue] = 0
        var pushes = Set(week(p).flatMap { $0.workout.exercises.filter { $0.exercise.pattern == .horizontalPush }.map { $0.exerciseID } })
        XCTAssertEqual(pushes, ["wall_pushup"])
        p.rungs[Ladder.push.rawValue] = 2
        pushes = Set(week(p).flatMap { $0.workout.exercises.filter { $0.exercise.pattern == .horizontalPush }.map { $0.exerciseID } })
        XCTAssertTrue(pushes.contains("pushup") || pushes.contains("knee_pushup"))
        XCTAssertFalse(pushes.contains("decline_pushup"))
    }

    func testSwapPreferencesAndExclusionsAreHonoured() {
        var p = T.profile(level: .intermediate, equipment: .dumbbells, weekdays: [2, 4, 6])
        let plain = week(p).flatMap { $0.workout.exercises.map { $0.exerciseID } }
        XCTAssertTrue(plain.contains("db_bench"))
        p.excludedExercises = ["db_bench"]
        XCTAssertFalse(week(p).flatMap { $0.workout.exercises.map { $0.exerciseID } }.contains("db_bench"))
        p.excludedExercises = []
        p.swapPreferences["db_bench"] = "db_incline_press"
        let swapped = week(p).flatMap { $0.workout.exercises.map { $0.exerciseID } }
        XCTAssertFalse(swapped.contains("db_bench"))
        XCTAssertTrue(swapped.contains("db_incline_press"))
    }

    // MARK: Quick workouts

    func testQuickWorkoutsFitTheirPurposeAndSkipStressfulMoves() {
        let p = T.profile(level: .intermediate, equipment: .fullGym, limitations: [.knees], lowImpact: true)
        for kind in QuickKind.allCases {
            let w = PlanGenerator.quick(kind, profile: p, history: [], now: T.day(0))
            XCTAssertGreaterThanOrEqual(w.exercises.count, 3, "\(kind)")
            XCTAssertTrue(w.exercises.allSatisfy { !$0.exercise.meta.stress.contains(.knees) && !$0.exercise.meta.isImpact }, "\(kind)")
            if kind != .noEquipment { XCTAssertLessThanOrEqual(w.minutes, 14, "\(kind)") }
            if kind != .mobility { XCTAssertTrue(w.exercises.allSatisfy { $0.exercise.equipment == .bodyweight }, "\(kind)") }
        }
    }
}

final class AlternativesTests: XCTestCase {
    private func setup(_ p: UserProfile, id: String) -> (PlannedExercise, Workout) {
        let planned = PlannedExercise(exerciseID: id, sets: 3, target: 8, repMin: 6, repMax: 10, restSeconds: 90, weightKg: 20)
        return (planned, Workout(id: "x", title: "t", subtitle: "s", theme: .chest, exercises: [planned]))
    }

    func testAlternativesNeverIncludeTheCurrentOrUsedExercisesAndAreAllowed() {
        let p = T.profile(level: .intermediate, equipment: .fullGym, limitations: [.shoulders])
        let (planned, workout) = setup(p, id: "bench_press")
        for reason in SwapReason.allCases {
            for alt in Alternatives.suggest(for: planned, in: workout, reason: reason, profile: p) {
                XCTAssertNotEqual(alt.exercise.id, "bench_press")
                XCTAssertTrue(PlanGenerator.isAllowed(alt.exercise, profile: p), "\(reason) \(alt.exercise.id)")
                XCTAssertFalse(alt.why.isEmpty)
            }
        }
    }

    func testTooHardOffersEasierOrSimilarButNeverHarder() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let (planned, workout) = setup(p, id: "bench_press")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .tooHard, profile: p)
        XCTAssertFalse(alts.isEmpty)
        XCTAssertTrue(alts.allSatisfy { $0.relation != .harder })
        XCTAssertEqual(alts.first?.relation, .easier)
    }

    func testTooEasyOffersHarderOrSimilarButNeverEasier() {
        var p = T.profile(level: .beginner, equipment: .bodyweight)
        p.rungs[Ladder.push.rawValue] = 1
        let (planned, workout) = setup(p, id: "wall_pushup")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .tooEasy, profile: p)
        XCTAssertFalse(alts.isEmpty)
        XCTAssertTrue(alts.allSatisfy { $0.relation != .easier })
        XCTAssertTrue(alts.contains { $0.exercise.id == "knee_pushup" })
    }

    func testAlternativesNeverJumpFarAboveTheRung() {
        var p = T.profile(level: .beginner, equipment: .bodyweight)
        p.rungs[Ladder.push.rawValue] = 0
        let (planned, workout) = setup(p, id: "wall_pushup")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .tooEasy, profile: p)
        XCTAssertFalse(alts.contains { $0.exercise.id == "pushup" || $0.exercise.id == "decline_pushup" })
    }

    func testPainAvoidsTheAreasInvolved() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let (planned, workout) = setup(p, id: "back_squat")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .pain, profile: p, painAreas: [.knees])
        XCTAssertFalse(alts.isEmpty)
        for alt in alts {
            XCTAssertFalse(alt.exercise.meta.stress.contains(.knees), alt.exercise.id)
            XCTAssertFalse(alt.exercise.meta.isImpact, alt.exercise.id)
        }
    }

    func testPainWithoutAnAreaAvoidsWhatTheExerciseStresses() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let (planned, workout) = setup(p, id: "deadlift")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .pain, profile: p)
        XCTAssertTrue(alts.allSatisfy { !$0.exercise.meta.stress.contains(.lowerBack) })
    }

    func testNoEquipmentOffersLessEquipmentClosestFirst() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let (planned, workout) = setup(p, id: "bench_press")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .noEquipment, profile: p)
        XCTAssertFalse(alts.isEmpty)
        XCTAssertTrue(alts.allSatisfy { $0.exercise.equipment.rank < Equipment.fullGym.rank })
        XCTAssertEqual(alts.first?.exercise.equipment, .dumbbells)
    }

    func testDislikeOffersTheSameMovementFirst() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let (planned, workout) = setup(p, id: "bench_press")
        let alts = Alternatives.suggest(for: planned, in: workout, reason: .dislike, profile: p)
        XCTAssertTrue(alts.allSatisfy { $0.exercise.pattern == .horizontalPush })
    }

    func testSuggestionsAreLimitedAndDeterministic() {
        let p = T.profile(level: .intermediate, equipment: .fullGym)
        let (planned, workout) = setup(p, id: "bench_press")
        let a = Alternatives.suggest(for: planned, in: workout, reason: .dislike, profile: p, limit: 3)
        let b = Alternatives.suggest(for: planned, in: workout, reason: .dislike, profile: p, limit: 3)
        XCTAssertLessThanOrEqual(a.count, 3)
        XCTAssertEqual(a.map { $0.exercise.id }, b.map { $0.exercise.id })
    }

    func testApplyingASwapScope() {
        var p = T.profile()
        let bench = ExerciseLibrary.exercise("bench_press")
        let press = ExerciseLibrary.exercise("db_bench")
        p.applySwap(original: bench, replacement: press, scope: .today)
        XCTAssertTrue(p.swapPreferences.isEmpty)
        p.applySwap(original: bench, replacement: press, scope: .always)
        XCTAssertEqual(p.swapPreferences["bench_press"], "db_bench")
        XCTAssertTrue(p.excludedExercises.isEmpty)
        p.applySwap(original: bench, replacement: press, scope: .neverShowOriginal, protecting: [.shoulders])
        XCTAssertEqual(p.excludedExercises, ["bench_press"])
        XCTAssertEqual(p.limitations, [.shoulders])
        p.applySwap(original: bench, replacement: press, scope: .neverShowOriginal, protecting: [.shoulders])
        XCTAssertEqual(p.excludedExercises, ["bench_press"])       // no duplicates
        XCTAssertEqual(p.limitations, [.shoulders])
    }
}
