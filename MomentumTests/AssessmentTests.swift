import XCTest
@testable import Momentum

final class AssessmentTests: EnglishTestCase {
    func testLevelFromHistoryAndFrequency() {
        XCTAssertEqual(Assessment.level(history: .never, frequency: .none, check: FitnessCheck()), .beginner)
        XCTAssertEqual(Assessment.level(history: .under6Months, frequency: .oneToTwo, check: FitnessCheck()), .beginner)
        XCTAssertEqual(Assessment.level(history: .sixTo24Months, frequency: .oneToTwo, check: FitnessCheck()), .intermediate)
        XCTAssertEqual(Assessment.level(history: .over2Years, frequency: .threeToFour, check: FitnessCheck()), .advanced)
    }

    func testAdvancedNeedsTwoYearsOfHistory() {
        XCTAssertEqual(Assessment.level(history: .sixTo24Months, frequency: .fivePlus, check: FitnessCheck()), .intermediate)
    }

    func testStrongCheckLiftsABeginnerOnce() {
        let strong = FitnessCheck(pushups: 25, squats: 40, plankSeconds: 75, pullups: nil)
        XCTAssertEqual(Assessment.level(history: .never, frequency: .none, check: strong), .intermediate)
        // Only two strong markers: stays a beginner.
        let almost = FitnessCheck(pushups: 25, squats: 40, plankSeconds: 30, pullups: nil)
        XCTAssertEqual(Assessment.level(history: .never, frequency: .none, check: almost), .beginner)
    }

    func testWeakCheckLowersOverconfidentPeople() {
        let weak = FitnessCheck(pushups: 2, squats: nil, plankSeconds: 15, pullups: nil)
        XCTAssertEqual(Assessment.level(history: .over2Years, frequency: .threeToFour, check: weak), .intermediate)
        XCTAssertEqual(Assessment.level(history: .sixTo24Months, frequency: .threeToFour, check: weak), .beginner)
        // A beginner cannot go lower.
        XCTAssertEqual(Assessment.level(history: .never, frequency: .none, check: weak), .beginner)
    }

    func testRungsFollowTheCheck() {
        let p = Assessment.place(history: .under6Months, frequency: .oneToTwo,
                                 check: FitnessCheck(pushups: 3, squats: 45, plankSeconds: 50, pullups: 0))
        XCTAssertEqual(p.rung(.push), 1)            // 1-4 push-ups -> knee push-ups
        XCTAssertEqual(p.rung(.verticalPush), 0)
        XCTAssertEqual(p.rung(.triceps), 0)
        XCTAssertEqual(p.rung(.squat), 1)           // 40+ squats
        XCTAssertEqual(p.rung(.lunge), 1)
        XCTAssertEqual(p.rung(.coreStability), 2)   // 45-89 s plank -> side plank
        XCTAssertEqual(p.rung(.pull), 0)
    }

    func testPushupBuckets() {
        func push(_ n: Int) -> Int {
            Assessment.place(history: .never, frequency: .none, check: FitnessCheck(pushups: n)).rung(.push)
        }
        XCTAssertEqual(push(0), 0)
        XCTAssertEqual(push(4), 1)
        XCTAssertEqual(push(5), 2)
        XCTAssertEqual(push(24), 2)
        XCTAssertEqual(push(25), 3)
    }

    func testSkippedCheckUsesLevelDefaults() {
        let beginner = Assessment.place(history: .never, frequency: .none, check: FitnessCheck())
        XCTAssertEqual(beginner.rung(.push), 0)
        let advanced = Assessment.place(history: .over2Years, frequency: .fivePlus, check: FitnessCheck())
        XCTAssertEqual(advanced.rung(.push), 3)
        XCTAssertEqual(advanced.level, .advanced)
    }

    func testEveryLadderGetsARung() {
        let p = Assessment.place(history: .never, frequency: .none, check: FitnessCheck())
        for ladder in Ladder.allCases { XCTAssertNotNil(p.rungs[ladder.rawValue], ladder.rawValue) }
    }
}

final class ExerciseMetaTests: EnglishTestCase {
    func testEveryExerciseHasMetadata() {
        for e in ExerciseLibrary.all {
            XCTAssertNotNil(ExerciseMetaTable.table[e.id], "missing meta: \(e.id)")
        }
        XCTAssertEqual(ExerciseMetaTable.table.count, ExerciseLibrary.all.count)
    }

    func testLibraryIDsAreUnique() {
        let ids = ExerciseLibrary.all.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testLaddersAreContiguousFromZero() {
        for ladder in Ladder.allCases {
            let rungs = (ExerciseMetaTable.ladders[ladder] ?? [:]).keys.sorted()
            XCTAssertEqual(rungs, Array(0...(rungs.last ?? 0)), ladder.rawValue)
        }
    }

    func testPatternMuscleMatchesExerciseMuscle() {
        // Volume bookkeeping relies on this.
        for e in ExerciseLibrary.all where e.pattern != .fullBody {
            XCTAssertEqual(e.pattern.muscle, e.muscle, e.id)
        }
    }

    func testFallbackPatternsStayInTheSameMuscle() {
        for pattern in Pattern.allCases {
            for fallback in pattern.fallbacks { XCTAssertEqual(fallback.muscle, pattern.muscle, "\(pattern)") }
        }
    }

    func testHighStressLiftsAreTagged() {
        XCTAssertTrue(ExerciseLibrary.exercise("deadlift").meta.stress.contains(.lowerBack))
        XCTAssertTrue(ExerciseLibrary.exercise("jump_squat").meta.isImpact)
        XCTAssertTrue(ExerciseLibrary.exercise("pushup").meta.stress.contains(.wrists))
        XCTAssertTrue(ExerciseLibrary.exercise("overhead_press").meta.stress.contains(.shoulders))
    }
}
