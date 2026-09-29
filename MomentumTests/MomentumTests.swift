import XCTest
@testable import Momentum

final class PlanGeneratorTests: XCTestCase {
    /// Monday, 5 January 2026.
    private var monday: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 5, hour: 9))!
    }

    private func profile(
        level: FitnessLevel = .beginner,
        days: Int = 3,
        equipment: Equipment = .bodyweight,
        goal: Goal = .stayFit,
        minutes: Int = 45
    ) -> UserProfile {
        var p = UserProfile()
        p.level = level
        p.daysPerWeek = days
        p.equipment = equipment
        p.goal = goal
        p.sessionMinutes = minutes
        p.startDate = monday
        p.onboarded = true
        return p
    }

    private func week(of profile: UserProfile, weeks: Int = 1) -> [(Date, Workout)] {
        var result: [(Date, Workout)] = []
        for offset in 0..<(7 * weeks) {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: monday)!
            if let workout = PlanGenerator.workout(on: day, profile: profile, history: [], now: day) {
                result.append((day, workout))
            }
        }
        return result
    }

    func testLibraryIDsAreUnique() {
        let ids = ExerciseLibrary.all.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertEqual(ExerciseLibrary.byID.count, ids.count)
    }

    func testTrainingDaysMatchRequestedDays() {
        for days in 1...6 {
            XCTAssertEqual(week(of: profile(days: days)).count, days, "days=\(days)")
        }
    }

    func testWorkoutsAreValidForEveryProfile() {
        for level in FitnessLevel.allCases {
            for equipment in Equipment.allCases {
                for goal in Goal.allCases {
                    for days in 1...6 {
                        let p = profile(level: level, days: days, equipment: equipment, goal: goal)
                        for (_, workout) in week(of: p, weeks: 3) {
                            let ids = workout.exercises.map { $0.exerciseID }
                            let label = "\(level) \(equipment) \(goal) \(days)d \(workout.title)"
                            XCTAssertEqual(ids.count, Set(ids).count, "duplicate exercise: \(label)")
                            XCTAssertGreaterThanOrEqual(workout.exercises.count, 3, label)
                            for planned in workout.exercises {
                                let exercise = planned.exercise
                                XCTAssertLessThanOrEqual(exercise.equipment.rank, equipment.rank, label)
                                XCTAssertLessThanOrEqual(exercise.level.rank, level.rank + 1, label)
                                XCTAssertGreaterThanOrEqual(planned.sets, 2, label)
                                XCTAssertGreaterThan(planned.target, 0, label)
                            }
                        }
                    }
                }
            }
        }
    }

    func testBodyweightPlansHaveNoWeights() {
        let p = profile(equipment: .bodyweight)
        for (_, workout) in week(of: p) {
            XCTAssertTrue(workout.exercises.allSatisfy { $0.weightKg == nil })
        }
    }

    func testDumbbellPlansSuggestWeights() {
        let p = profile(level: .intermediate, days: 4, equipment: .dumbbells)
        let weights = week(of: p).flatMap { $0.1.exercises }.compactMap { $0.weightKg }
        XCTAssertFalse(weights.isEmpty)
        XCTAssertTrue(weights.allSatisfy { $0 >= 1 })
    }

    func testSessionFitsTimeBudget() {
        for minutes in [20, 30, 45, 60] {
            let p = profile(level: .intermediate, days: 3, equipment: .fullGym, minutes: minutes)
            for (_, workout) in week(of: p) {
                XCTAssertLessThanOrEqual(workout.minutes, minutes + 6, "\(minutes) min budget")
            }
        }
    }

    func testAdvancedGetsMoreVolumeThanBeginner() {
        let beginner = week(of: profile(level: .beginner)).first!.1
        let advanced = week(of: profile(level: .advanced)).first!.1
        XCTAssertGreaterThan(advanced.exercises[0].sets, beginner.exercises[0].sets)
    }

    func testExercisesRotateAcrossWeeks() {
        let p = profile(level: .intermediate, days: 3, equipment: .dumbbells)
        let all = week(of: p, weeks: 4).map { $0.1.exercises.map { $0.exerciseID } }
        XCTAssertGreaterThan(Set(all.map { $0.joined(separator: ",") }).count, 3)
    }

    func testQuickWorkouts() {
        let p = profile(level: .intermediate, equipment: .fullGym)
        for kind in QuickKind.allCases {
            let workout = PlanGenerator.quick(kind, profile: p, history: [], now: monday)
            XCTAssertGreaterThanOrEqual(workout.exercises.count, 3, "\(kind)")
            XCTAssertLessThanOrEqual(workout.minutes, kind == .noEquipment ? 60 : 14, "\(kind)")
            XCTAssertTrue(workout.exercises.allSatisfy { $0.exercise.equipment == .bodyweight }, "\(kind)")
        }
    }

    func testAlternativesShareMuscleAndExcludeCurrent() {
        let p = profile(level: .intermediate, days: 3, equipment: .dumbbells)
        let workout = week(of: p).first!.1
        let planned = workout.exercises[0]
        let options = PlanGenerator.alternatives(for: planned, in: workout, profile: p)
        XCTAssertTrue(options.allSatisfy { $0.muscle == planned.exercise.muscle })
        XCTAssertFalse(options.contains { $0.id == planned.exerciseID })
    }
}

final class AdaptiveEngineTests: XCTestCase {
    func testTooEasyRaisesIntensity() {
        let outcome = AdaptiveEngine.evaluate(level: .beginner, intensity: 0, feedback: .tooEasy, completion: 1)
        XCTAssertEqual(outcome.intensity, 1)
        XCTAssertEqual(outcome.level, .beginner)
    }

    func testTooHardLowersIntensity() {
        let outcome = AdaptiveEngine.evaluate(level: .intermediate, intensity: 0, feedback: .tooHard, completion: 1)
        XCTAssertEqual(outcome.intensity, -1)
    }

    func testJustRightKeepsIntensity() {
        let outcome = AdaptiveEngine.evaluate(level: .intermediate, intensity: 2, feedback: .justRight, completion: 1)
        XCTAssertEqual(outcome.intensity, 2)
        XCTAssertNil(outcome.message)
    }

    func testLowCompletionForcesEasier() {
        let outcome = AdaptiveEngine.evaluate(level: .intermediate, intensity: 0, feedback: .justRight, completion: 0.4)
        XCTAssertEqual(outcome.intensity, -1)
    }

    func testPromotionAtCeiling() {
        let outcome = AdaptiveEngine.evaluate(level: .beginner, intensity: 3, feedback: .tooEasy, completion: 1)
        XCTAssertEqual(outcome.level, .intermediate)
        XCTAssertEqual(outcome.intensity, 0)
        XCTAssertNotNil(outcome.message)
    }

    func testDemotionAtFloor() {
        let outcome = AdaptiveEngine.evaluate(level: .advanced, intensity: -3, feedback: .tooHard, completion: 1)
        XCTAssertEqual(outcome.level, .intermediate)
        XCTAssertEqual(outcome.intensity, 0)
    }

    func testClampsAtExtremes() {
        let top = AdaptiveEngine.evaluate(level: .advanced, intensity: 3, feedback: .tooEasy, completion: 1)
        XCTAssertEqual(top.level, .advanced)
        XCTAssertEqual(top.intensity, 3)
        let bottom = AdaptiveEngine.evaluate(level: .beginner, intensity: -3, feedback: .tooHard, completion: 1)
        XCTAssertEqual(bottom.level, .beginner)
        XCTAssertEqual(bottom.intensity, -3)
    }

    func testComebackEasesIntensityAfterBreak() {
        var profile = UserProfile()
        profile.intensity = 2
        let now = Date()
        let old = Calendar.current.date(byAdding: .day, value: -12, to: now)!
        let session = WorkoutSession(
            date: old, title: "x", durationSeconds: 1800, calories: 200,
            plannedSets: 10, completedSets: 10, logs: [], feedback: .justRight
        )
        XCTAssertEqual(AdaptiveEngine.effectiveIntensity(profile: profile, history: [session], now: now), -1)
        XCTAssertEqual(AdaptiveEngine.effectiveIntensity(profile: profile, history: [], now: now), 2)
    }
}

final class WeightAdvisorTests: XCTestCase {
    private func session(weight: Double, reps: Int, sets: Int, target: Int, daysAgo: Int) -> WorkoutSession {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let log = ExerciseLog(
            exerciseID: "goblet_squat",
            targetSets: 3,
            target: target,
            sets: Array(repeating: SetLog(reps: reps, weightKg: weight, seconds: 0), count: sets)
        )
        return WorkoutSession(
            date: date, title: "t", durationSeconds: 1800, calories: 100,
            plannedSets: 3, completedSets: sets, logs: [log], feedback: .justRight
        )
    }

    private let goblet = ExerciseLibrary.exercise("goblet_squat")

    func testFirstTimeEstimateScalesWithBodyweightAndLevel() {
        var light = UserProfile(); light.weightKg = 60; light.level = .beginner
        var heavy = UserProfile(); heavy.weightKg = 100; heavy.level = .advanced
        let a = WeightAdvisor.suggest(for: goblet, profile: light, history: [])!
        let b = WeightAdvisor.suggest(for: goblet, profile: heavy, history: [])!
        XCTAssertGreaterThan(b, a)
    }

    func testBodyweightExerciseHasNoSuggestion() {
        XCTAssertNil(WeightAdvisor.suggest(for: ExerciseLibrary.exercise("pushup"), profile: UserProfile(), history: []))
    }

    func testIncreasesAfterHittingAllReps() {
        let history = [session(weight: 12, reps: 12, sets: 3, target: 12, daysAgo: 2)]
        let next = WeightAdvisor.suggest(for: goblet, profile: UserProfile(), history: history)!
        XCTAssertGreaterThan(next, 12)
    }

    func testHoldsWhenSlightlyShort() {
        let history = [session(weight: 12, reps: 10, sets: 3, target: 12, daysAgo: 2)]
        XCTAssertEqual(WeightAdvisor.suggest(for: goblet, profile: UserProfile(), history: history), 12)
    }

    func testDropsWhenFarShort() {
        let history = [session(weight: 20, reps: 6, sets: 3, target: 12, daysAgo: 2)]
        let next = WeightAdvisor.suggest(for: goblet, profile: UserProfile(), history: history)!
        XCTAssertLessThan(next, 20)
    }

    func testUsesMostRecentSession() {
        let history = [
            session(weight: 8, reps: 12, sets: 3, target: 12, daysAgo: 30),
            session(weight: 16, reps: 10, sets: 3, target: 12, daysAgo: 1)
        ]
        XCTAssertEqual(WeightAdvisor.suggest(for: goblet, profile: UserProfile(), history: history), 16)
    }
}

final class UnitTests: XCTestCase {
    func testWeightConversionRoundTrips() {
        let kg = 82.5
        let pounds = UnitSystem.imperial.displayWeight(kg)
        XCTAssertEqual(UnitSystem.imperial.kg(fromDisplay: pounds), kg, accuracy: 0.0001)
    }

    func testFormatting() {
        XCTAssertEqual(UnitSystem.metric.formatWeight(20), "20 kg")
        XCTAssertEqual(UnitSystem.metric.formatWeight(12.5), "12.5 kg")
    }
}

final class MotionTests: XCTestCase {
    func testEveryExerciseHasAWellFormedMotion() {
        XCTAssertFalse(MotionLibrary.all.isEmpty, "MotionData.json failed to decode")
        for exercise in ExerciseLibrary.all {
            guard let motion = MotionLibrary.motion(for: exercise.id) else {
                XCTFail("no animation for \(exercise.id)")
                continue
            }
            XCTAssertEqual(motion.bounds.count, 4, exercise.id)
            XCTAssertGreaterThanOrEqual(motion.frames.count, 2, exercise.id)
            XCTAssertTrue(motion.frames.allSatisfy { $0.count == 14 }, exercise.id)
            XCTAssertGreaterThan(motion.dur, 0.2, exercise.id)
            XCTAssertEqual(motion.pose(at: 1.234).count, 14, exercise.id)
        }
    }

    func testNoAnimationForUnknownExercise() {
        XCTAssertNil(MotionLibrary.motion(for: "does_not_exist"))
    }

    func testBlendTakesShortestWayAroundTheCircle() {
        var a = [Double](repeating: 0, count: 14)
        var b = a
        a[2] = 170
        b[2] = -170
        let mid = Motion.blend(a, b, 0.5)
        XCTAssertEqual(abs(mid[2]), 180, accuracy: 0.001)
    }

    func testPoseLoopsSmoothly() throws {
        let motion = try XCTUnwrap(MotionLibrary.motion(for: "pushup"))
        let start = motion.pose(at: 0)
        let wrapped = motion.pose(at: motion.dur * Double(motion.frames.count))
        for (x, y) in zip(start, wrapped) { XCTAssertEqual(x, y, accuracy: 0.001) }
    }

    func testStandingFeetSitOnTheFloor() throws {
        let motion = try XCTUnwrap(MotionLibrary.motion(for: "bw_squat"))
        for frame in motion.frames {
            let joints = Skeleton.joints(frame, front: motion.isFront)
            XCTAssertEqual(joints.ankleNear.y, 0.05, accuracy: 0.02)
        }
    }
}
