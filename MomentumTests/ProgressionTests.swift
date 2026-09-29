import XCTest
@testable import Momentum

final class ProgressionTests: XCTestCase {
    private let bench = "db_bench"          // dumbbell compound (per-hand weights)
    private func profile(_ goal: Goal = .buildMuscle, maxDumbbell: Double = 0) -> UserProfile {
        T.profile(level: .intermediate, goal: goal, equipment: .dumbbells, maxDumbbell: maxDumbbell)
    }

    private func decide(_ id: String, _ p: UserProfile, _ history: [WorkoutSession], hold: Bool = false) -> Decision {
        Progression.decide(exercise: ExerciseLibrary.exercise(id), profile: p, history: history, range: T.range(id, p), holdLoad: hold)
    }

    // MARK: Ranges and rest

    func testRepRangesAreSaneForEveryCombination() {
        for e in ExerciseLibrary.all {
            for goal in Goal.allCases {
                for level in FitnessLevel.allCases {
                    let r = Progression.repRange(for: e, goal: goal, level: level)
                    XCTAssertLessThanOrEqual(r.min, r.max, "\(e.id) \(goal) \(level)")
                    XCTAssertGreaterThanOrEqual(r.min, 3, "\(e.id)")
                    XCTAssertLessThanOrEqual(r.max, 45, "\(e.id)")
                }
            }
        }
    }

    func testStrengthGoalUsesHeavyRangesOnlyOnBarbellMainLifts() {
        XCTAssertEqual(Progression.repRange(for: ExerciseLibrary.exercise("bench_press"), goal: .getStronger, level: .advanced), RepRange(min: 3, max: 6))
        XCTAssertEqual(Progression.repRange(for: ExerciseLibrary.exercise("db_lunge"), goal: .getStronger, level: .advanced), RepRange(min: 5, max: 8))
        XCTAssertEqual(Progression.repRange(for: ExerciseLibrary.exercise("bench_press"), goal: .buildMuscle, level: .intermediate), RepRange(min: 6, max: 10))
    }

    func testRestScalesWithRoleGoalAndAge() {
        let squat = ExerciseLibrary.exercise("back_squat")
        let heavy = RepRange(min: 3, max: 6)
        XCTAssertEqual(Progression.rest(for: squat, range: heavy, goal: .getStronger, age: 30), 150)
        XCTAssertEqual(Progression.rest(for: squat, range: RepRange(min: 6, max: 10), goal: .buildMuscle, age: 30), 120)
        let curl = ExerciseLibrary.exercise("db_curl")
        XCTAssertEqual(Progression.rest(for: curl, range: RepRange(min: 10, max: 15), goal: .buildMuscle, age: 30), 60)
        XCTAssertLessThan(Progression.rest(for: curl, range: RepRange(min: 10, max: 15), goal: .loseFat, age: 30), 60)
        XCTAssertGreaterThan(Progression.rest(for: curl, range: RepRange(min: 10, max: 15), goal: .buildMuscle, age: 60), 60)
        XCTAssertEqual(Progression.rest(for: ExerciseLibrary.exercise("plank"), range: RepRange(min: 20, max: 45), goal: .stayFit, age: 30), 40)
    }

    // MARK: Load helpers

    func testLoadStepsAndMinimums() {
        let db = ExerciseLibrary.exercise("db_curl")
        XCTAssertEqual(Progression.step(for: db, at: 8), 1)
        XCTAssertEqual(Progression.step(for: db, at: 20), 2)
        XCTAssertEqual(Progression.step(for: db, at: 40), 2.5)
        XCTAssertEqual(Progression.step(for: ExerciseLibrary.exercise("back_squat"), at: 100), 5)
        XCTAssertEqual(Progression.step(for: ExerciseLibrary.exercise("bench_press"), at: 60), 2.5)
        // An empty barbell is 20 kg.
        XCTAssertEqual(Progression.roundLoad(8, for: ExerciseLibrary.exercise("bench_press")), 20)
        XCTAssertEqual(Progression.roundLoad(51, for: ExerciseLibrary.exercise("bench_press")), 50)
        XCTAssertEqual(Progression.roundLoad(59, for: ExerciseLibrary.exercise("back_squat"), down: true), 55)
    }

    func testInitialLoadDependsOnBodyAndPerson() {
        let goblet = ExerciseLibrary.exercise("goblet_squat")
        var male = T.profile(level: .intermediate, sex: .male, weight: 80)
        var female = male
        female.sex = .female
        XCTAssertGreaterThan(Progression.initialLoad(for: goblet, profile: male)!, 0)
        let bench = ExerciseLibrary.exercise("db_bench")
        XCTAssertLessThan(Progression.initialLoad(for: bench, profile: female)!, Progression.initialLoad(for: bench, profile: male)!)
        male.age = 70
        XCTAssertLessThan(Progression.initialLoad(for: bench, profile: male)!, Progression.initialLoad(for: bench, profile: T.profile(level: .intermediate, sex: .male, weight: 80))!)
        male.age = 30
        male.level = .beginner
        XCTAssertLessThan(Progression.initialLoad(for: bench, profile: male)!, Progression.initialLoad(for: bench, profile: T.profile(level: .intermediate, sex: .male, weight: 80))!)
    }

    func testInitialLoadRespectsTheHeaviestDumbbell() {
        var p = T.profile(level: .advanced, equipment: .dumbbells, maxDumbbell: 12, weight: 100)
        p.sex = .male
        XCTAssertLessThanOrEqual(Progression.initialLoad(for: ExerciseLibrary.exercise("goblet_squat"), profile: p)!, 12)
    }

    func testBodyweightExercisesHaveNoLoad() {
        XCTAssertNil(Progression.initialLoad(for: ExerciseLibrary.exercise("pushup"), profile: T.profile()))
    }

    func testEstimatedOneRepMax() {
        XCTAssertEqual(Progression.estimatedOneRepMax(weightKg: 100, reps: 5)!, 100 * (1 + 5.0 / 30), accuracy: 0.001)
        XCTAssertNil(Progression.estimatedOneRepMax(weightKg: 100, reps: 25))
        XCTAssertNil(Progression.estimatedOneRepMax(weightKg: 0, reps: 5))
    }

    // MARK: Double progression (loaded)

    func testFirstTimeStartsLightInTheMiddleOfTheRange() {
        let p = profile()
        let d = decide(bench, p, [])
        let r = T.range(bench, p)
        XCTAssertEqual(d.target, (r.min + r.max) / 2)
        XCTAssertNotNil(d.weightKg)
        XCTAssertTrue(d.reason?.contains("First time") == true)
    }

    func testAddsOneStepWhenEverySetHitsTheTop() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: Array(repeating: (r.max, 20.0), count: 3), min: r.min, max: r.max)])]
        let d = decide(bench, p, h)
        XCTAssertEqual(d.weightKg, 22)                 // 20 kg dumbbell -> +2 kg
        XCTAssertEqual(d.target, r.min)
        XCTAssertTrue(d.reason?.hasPrefix("Up ") == true)
    }

    func testAddsTwoStepsWhenTheTopWasBeatenByThree() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: Array(repeating: (r.max + 3, 20.0), count: 3), min: r.min, max: r.max)])]
        XCTAssertEqual(decide(bench, p, h).weightKg, 24)
    }

    func testHoldsWhenTheTopWasHitButItFeltHard() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: Array(repeating: (r.max, 20.0), count: 3), min: r.min, max: r.max, effort: .hard)])]
        let d = decide(bench, p, h)
        XCTAssertEqual(d.weightKg, 20)
        XCTAssertTrue(d.reason?.contains("hard") == true)
    }

    func testEasyAndWithinOneRepCountsAsReachingTheTop() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: [(r.max - 1, 20), (r.max, 20), (r.max - 1, 20)], min: r.min, max: r.max, effort: .easy)])]
        XCTAssertEqual(decide(bench, p, h).weightKg, 22)
        let notEasy = [T.session(on: T.day(-3), logs: [T.log(bench, sets: [(r.max - 1, 20), (r.max, 20), (r.max - 1, 20)], min: r.min, max: r.max, effort: .good)])]
        XCTAssertEqual(decide(bench, p, notEasy).weightKg, 20)
    }

    func testWithinRangeHoldsTheWeightAndAsksForOneMoreRep() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: [(r.min + 1, 20), (r.min + 2, 20), (r.min + 1, 20)], min: r.min, max: r.max)])]
        let d = decide(bench, p, h)
        XCTAssertEqual(d.weightKg, 20)
        XCTAssertEqual(d.target, r.min + 2)            // weakest set + 1
    }

    func testOneShortSetRepeatsTheWeight() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: [(r.min + 1, 20), (r.min + 1, 20), (r.min - 1, 20)], min: r.min, max: r.max)])]
        let d = decide(bench, p, h)
        XCTAssertEqual(d.weightKg, 20)
        XCTAssertEqual(d.target, r.min)
    }

    func testMostSetsBelowTheMinimumRepeatsOnceThenDropsTenPercent() {
        let p = profile()
        let r = T.range(bench, p)
        let miss = T.log(bench, sets: [(r.min - 1, 30), (r.min - 1, 30), (r.min - 2, 30)], min: r.min, max: r.max)
        let once = decide(bench, p, [T.session(on: T.day(-3), logs: [miss])])
        XCTAssertEqual(once.weightKg, 30)
        let twice = decide(bench, p, [T.session(on: T.day(-6), logs: [miss]), T.session(on: T.day(-3), logs: [miss])])
        XCTAssertLessThan(twice.weightKg!, 30)
        XCTAssertGreaterThanOrEqual(twice.weightKg!, 26)     // about 10%, on a 2 kg step
    }

    func testBadlyOverestimatedLoadDropsImmediately() {
        let p = profile()
        let r = T.range(bench, p)
        let awful = T.log(bench, sets: [(r.min - 5, 30), (r.min - 5, 30), (r.min - 6, 30)], min: r.min, max: r.max)
        let d = decide(bench, p, [T.session(on: T.day(-3), logs: [awful])])
        XCTAssertLessThan(d.weightKg!, 30)
        XCTAssertTrue(d.reason?.contains("much heavier") == true)
    }

    func testSkippedSetsDoNotTriggerProgression() {
        let p = profile()
        let r = T.range(bench, p)
        // Planned 4 sets, did 1 at the top.
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: [(r.max, 20)], targetSets: 4, min: r.min, max: r.max)])]
        XCTAssertEqual(decide(bench, p, h).weightKg, 20)
    }

    func testDumbbellCapStopsAddingWeightAndExtendsReps() {
        let p = profile(maxDumbbell: 24)
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: Array(repeating: (r.max, 24.0), count: 3), min: r.min, max: r.max)])]
        let d = decide(bench, p, h)
        XCTAssertEqual(d.weightKg, 24)
        XCTAssertGreaterThan(d.repMax, r.max)
        XCTAssertLessThanOrEqual(d.repMax, 20)
        XCTAssertTrue(d.reason?.contains("heaviest dumbbell") == true)
    }

    func testStepOverTheCapIsClampedToTheCap() {
        let p = profile(maxDumbbell: 21)
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: Array(repeating: (r.max, 20.0), count: 3), min: r.min, max: r.max)])]
        XCTAssertLessThanOrEqual(decide(bench, p, h).weightKg!, 21)
    }

    func testLowReadinessNeverIncreasesTheWeight() {
        let p = profile()
        let r = T.range(bench, p)
        let h = [T.session(on: T.day(-3), logs: [T.log(bench, sets: Array(repeating: (r.max, 20.0), count: 3), min: r.min, max: r.max)])]
        let d = decide(bench, p, h, hold: true)
        XCTAssertEqual(d.weightKg, 20)
        XCTAssertTrue(d.reason?.contains("not feeling great") == true)
    }

    func testUsesTheMostRecentSession() {
        let p = profile()
        let r = T.range(bench, p)
        let old = T.session(on: T.day(-30), logs: [T.log(bench, sets: Array(repeating: (r.max, 10.0), count: 3), min: r.min, max: r.max)])
        let recent = T.session(on: T.day(-3), logs: [T.log(bench, sets: [(r.min + 1, 20), (r.min + 1, 20), (r.min + 1, 20)], min: r.min, max: r.max)])
        XCTAssertEqual(decide(bench, p, [old, recent]).weightKg, 20)
    }

    // MARK: Bodyweight and holds

    func testBodyweightAddsARepUntilTheTop() {
        let p = T.profile(level: .beginner, goal: .stayFit, equipment: .bodyweight)
        let r = T.range("knee_pushup", p)
        let h = [T.session(on: T.day(-3), logs: [T.log("knee_pushup", sets: [(r.min + 1, 0), (r.min + 2, 0)], min: r.min, max: r.max)])]
        let d = decide("knee_pushup", p, h)
        XCTAssertNil(d.weightKg)
        XCTAssertEqual(d.target, r.min + 2)
    }

    func testBodyweightAtTheTopExtendsTheRangeWhenNothingHarderExists() {
        let p = T.profile(level: .beginner, goal: .stayFit, equipment: .bodyweight)
        let r = T.range("knee_pushup", p)
        let h = [T.session(on: T.day(-3), logs: [T.log("knee_pushup", sets: [(r.max, 0), (r.max, 0)], min: r.min, max: r.max)])]
        let d = decide("knee_pushup", p, h)
        XCTAssertGreaterThan(d.repMax, r.max)
        XCTAssertGreaterThan(d.target, r.max)
    }

    func testBodyweightCeilingAddsASet() {
        let p = T.profile(level: .beginner, goal: .stayFit, equipment: .bodyweight)
        let r = T.range("knee_pushup", p)
        let h = [T.session(on: T.day(-3), logs: [T.log("knee_pushup", sets: [(25, 0), (25, 0)], min: r.min, max: 25)])]
        XCTAssertTrue(decide("knee_pushup", p, h).addSet)
    }

    func testHoldsProgressInSeconds() {
        let p = T.profile(level: .intermediate, goal: .stayFit, equipment: .bodyweight)
        let r = T.range("plank", p)
        let h = [T.session(on: T.day(-3), logs: [T.log("plank", sets: [(r.min + 5, 0), (r.min + 10, 0)], min: r.min, max: r.max, seconds: true)])]
        let d = decide("plank", p, h)
        XCTAssertEqual(d.target, r.min + 10)
    }

    // MARK: Comeback

    func testComebackFactors() {
        XCTAssertEqual(Comeback.factor(daysSinceLast: 3), 1.0)
        XCTAssertEqual(Comeback.factor(daysSinceLast: 12), 0.95)
        XCTAssertEqual(Comeback.factor(daysSinceLast: 25), 0.85)
        XCTAssertEqual(Comeback.factor(daysSinceLast: 40), 0.75)
        XCTAssertEqual(Comeback.factor(daysSinceLast: 90), 0.65)
        XCTAssertEqual(Comeback.setsToRemove(daysSinceLast: 13), 0)
        XCTAssertEqual(Comeback.setsToRemove(daysSinceLast: 14), 1)
    }
}
