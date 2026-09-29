import XCTest
@testable import Momentum

final class PeriodizationTests: XCTestCase {
    func testBlockLengthsByLevel() {
        XCTAssertEqual(Periodization.blockLength(for: .beginner), 6)
        XCTAssertEqual(Periodization.blockLength(for: .intermediate), 5)
        XCTAssertEqual(Periodization.blockLength(for: .advanced), 4)
    }

    func testLastWeekOfEveryBlockIsADeload() {
        for level in FitnessLevel.allCases {
            let p = T.profile(level: level)
            let length = Periodization.blockLength(for: level)
            for week in 0..<(length * 3) {
                let phase = Periodization.phase(on: T.week(week), profile: p, history: [], now: T.week(week))
                XCTAssertEqual(phase.isDeload, week % length == length - 1, "\(level) week \(week)")
                XCTAssertEqual(phase.weekInBlock, week % length)
            }
        }
    }

    func testRepsInReserveSchedule() {
        XCTAssertEqual(Periodization.repsInReserve(weekInBlock: 0, level: .intermediate, isDeload: false), 3)
        XCTAssertEqual(Periodization.repsInReserve(weekInBlock: 1, level: .intermediate, isDeload: false), 2)
        XCTAssertEqual(Periodization.repsInReserve(weekInBlock: 3, level: .intermediate, isDeload: false), 1)
        XCTAssertEqual(Periodization.repsInReserve(weekInBlock: 3, level: .beginner, isDeload: false), 2)   // beginners never below 2
        XCTAssertEqual(Periodization.repsInReserve(weekInBlock: 3, level: .advanced, isDeload: true), 4)
    }

    func testForcedDeloadOverridesTheSchedule() {
        var p = T.profile(level: .intermediate)
        p.deloadWeekStart = TrainingCalendar.weekStart(of: T.week(1))
        XCTAssertTrue(Periodization.phase(on: T.week(1), profile: p, history: [], now: T.week(1)).isDeload)
        XCTAssertFalse(Periodization.phase(on: T.week(2), profile: p, history: [], now: T.week(1)).isDeload)
    }

    func testALongBreakRestartsTheBlock() {
        let p = T.profile(level: .intermediate)
        let old = T.session(on: T.week(0), logs: [])
        // Week 3 would be build week 4, but 3 weeks off restarts at week 1.
        let phase = Periodization.phase(on: T.week(3), profile: p, history: [old], now: T.week(3))
        XCTAssertEqual(phase.weekInBlock, 0)
    }

    func testVariantsChangeOnlyAtBlockBoundaries() {
        let p = T.profile(level: .intermediate)
        let length = Periodization.blockLength(for: .intermediate)
        XCTAssertEqual(Periodization.blockNumber(on: T.week(0), profile: p), 0)
        XCTAssertEqual(Periodization.blockNumber(on: T.week(length - 1), profile: p), 0)
        XCTAssertEqual(Periodization.blockNumber(on: T.week(length), profile: p), 1)
    }
}

final class RecoveryTests: XCTestCase {
    private func failing(_ id: String = "db_bench") -> ExerciseLog {
        T.log(id, sets: [(3, 20), (3, 20), (2, 20)], min: 8, max: 12)
    }

    private func bad(_ offset: Int) -> WorkoutSession {
        T.session(on: T.day(offset), logs: [failing()], feedback: .tooHard, planned: 10, done: 6)
    }

    func testFatigueScoreCombinesSignals() {
        let s = Recovery.fatigueScore(history: [bad(-1)], now: T.day(0))
        XCTAssertEqual(s.score, 2 + 2 + 1)      // too hard + under 75% + one failed exercise
        XCTAssertEqual(s.badSessions, 1)
    }

    func testTwoBadSessionsTriggerADeloadOnceThereIsABaseline() {
        var p = T.profile(level: .intermediate)
        p.startDate = T.day(-60)
        let base = (1...3).map { T.okSession(on: T.day(-30 - $0)) }
        let history = base + [bad(-3), bad(-1)]
        let phase = Periodization.phase(on: T.day(0), profile: p, history: history, now: T.day(0))
        XCTAssertTrue(Recovery.shouldDeload(profile: p, history: history, phase: phase, now: T.day(0)))
    }

    func testNoAutomaticDeloadInTheFirstTwoWeeks() {
        var p = T.profile(level: .intermediate)
        p.startDate = T.day(-5)
        let history = [bad(-3), bad(-2), bad(-1), bad(0)]
        let phase = Periodization.phase(on: T.day(0), profile: p, history: history, now: T.day(0))
        XCTAssertFalse(Recovery.shouldDeload(profile: p, history: history, phase: phase, now: T.day(0)))
    }

    func testOneBadSessionIsNotEnough() {
        var p = T.profile(level: .intermediate)
        p.startDate = T.day(-60)
        let history = (1...4).map { T.okSession(on: T.day(-10 - $0)) } + [bad(-1)]
        let phase = Periodization.phase(on: T.day(0), profile: p, history: history, now: T.day(0))
        XCTAssertFalse(Recovery.shouldDeload(profile: p, history: history, phase: phase, now: T.day(0)))
    }

    func testNoSecondDeloadRightAfterOne() {
        var p = T.profile(level: .intermediate)
        p.startDate = T.day(-90)
        p.deloadWeekStart = TrainingCalendar.weekStart(of: T.day(-8))
        let history = (1...3).map { T.okSession(on: T.day(-40 - $0)) } + [bad(-3), bad(-1)]
        let phase = Periodization.phase(on: T.day(0), profile: p, history: history, now: T.day(0))
        XCTAssertFalse(Recovery.shouldDeload(profile: p, history: history, phase: phase, now: T.day(0)))
    }
}

final class AdaptiveEngineTests: XCTestCase {
    // MARK: Feedback hysteresis

    func testOneEasySessionDoesNotMoveTheDifficulty() {
        let o = AdaptiveEngine.evaluate(level: .beginner, intensity: 0, feedback: .tooEasy, completion: 1, previousFeedback: .justRight)
        XCTAssertEqual(o.intensity, 0)
        XCTAssertNil(o.message)
    }

    func testTwoEasySessionsInARowRaiseIt() {
        let o = AdaptiveEngine.evaluate(level: .beginner, intensity: 0, feedback: .tooEasy, completion: 1, previousFeedback: .tooEasy)
        XCTAssertEqual(o.intensity, 1)
        XCTAssertNotNil(o.message)
    }

    func testTwoHardSessionsInARowLowerIt() {
        let o = AdaptiveEngine.evaluate(level: .intermediate, intensity: 0, feedback: .tooHard, completion: 1, previousFeedback: .tooHard)
        XCTAssertEqual(o.intensity, -1)
    }

    func testFinishingUnderSixtyPercentLowersItImmediately() {
        let o = AdaptiveEngine.evaluate(level: .intermediate, intensity: 0, feedback: .justRight, completion: 0.4, previousFeedback: nil)
        XCTAssertEqual(o.intensity, -1)
    }

    func testLevelChangesAtTheEndsAndOnlyAfterTheCooldown() {
        let up = AdaptiveEngine.evaluate(level: .beginner, intensity: 3, feedback: .tooEasy, completion: 1, previousFeedback: .tooEasy)
        XCTAssertEqual(up.level, .intermediate)
        XCTAssertEqual(up.intensity, 0)
        let blocked = AdaptiveEngine.evaluate(level: .beginner, intensity: 3, feedback: .tooEasy, completion: 1, previousFeedback: .tooEasy, canChangeLevel: false)
        XCTAssertEqual(blocked.level, .beginner)
        XCTAssertEqual(blocked.intensity, 3)
        let down = AdaptiveEngine.evaluate(level: .advanced, intensity: -3, feedback: .tooHard, completion: 1, previousFeedback: .tooHard)
        XCTAssertEqual(down.level, .intermediate)
        let floor = AdaptiveEngine.evaluate(level: .beginner, intensity: -3, feedback: .tooHard, completion: 1, previousFeedback: .tooHard)
        XCTAssertEqual(floor.level, .beginner)
        XCTAssertEqual(floor.intensity, -3)
    }

    // MARK: Rungs

    private func bodyweightProfile() -> UserProfile {
        var p = T.profile(level: .beginner, goal: .stayFit, equipment: .bodyweight)
        p.startDate = T.day(-100)
        p.rungs[Ladder.push.rawValue] = 0
        return p
    }

    func testReachingTheTopMovesUpTheLadder() {
        let p = bodyweightProfile()
        let r = T.range("wall_pushup", p)
        let s = T.session(on: T.day(0), logs: [T.log("wall_pushup", sets: [(r.max, 0), (r.max, 0)], min: r.min, max: r.max)])
        let out = AdaptiveEngine.apply(session: s, to: p, history: [s], previousSessionDate: nil)
        XCTAssertEqual(out.profile.rungs[Ladder.push.rawValue], 1)
        XCTAssertTrue(out.messages.contains { $0.contains("Knee Push-Up") })
    }

    func testNoSecondRungChangeWithinTwoWeeks() {
        var p = bodyweightProfile()
        p.rungChangedAt[Ladder.push.rawValue] = T.day(-5)
        let r = T.range("wall_pushup", p)
        let s = T.session(on: T.day(0), logs: [T.log("wall_pushup", sets: [(r.max, 0), (r.max, 0)], min: r.min, max: r.max)])
        let out = AdaptiveEngine.apply(session: s, to: p, history: [s], previousSessionDate: nil)
        XCTAssertEqual(out.profile.rungs[Ladder.push.rawValue], 0)
    }

    func testDoesNotClimbIntoAProtectedExercise() {
        var p = bodyweightProfile()
        p.limitations = [.wrists]                       // knee push-ups stress the wrists
        let r = T.range("wall_pushup", p)
        let s = T.session(on: T.day(0), logs: [T.log("wall_pushup", sets: [(r.max, 0), (r.max, 0)], min: r.min, max: r.max)])
        let out = AdaptiveEngine.apply(session: s, to: p, history: [s], previousSessionDate: nil)
        XCTAssertEqual(out.profile.rungs[Ladder.push.rawValue], 0)
    }

    func testSteppingBackNeedsThreeStruggles() {
        var p = bodyweightProfile()
        p.rungs[Ladder.push.rawValue] = 1
        let r = T.range("knee_pushup", p)
        let struggle = { (offset: Int) in
            T.session(on: T.day(offset), logs: [T.log("knee_pushup", sets: [(2, 0), (2, 0)], min: r.min, max: r.max)])
        }
        let two = [struggle(-6), struggle(-3)]
        XCTAssertEqual(AdaptiveEngine.apply(session: two[1], to: p, history: two, previousSessionDate: nil).profile.rungs[Ladder.push.rawValue], 1)
        let three = [struggle(-6), struggle(-3), struggle(0)]
        let out = AdaptiveEngine.apply(session: three[2], to: p, history: three, previousSessionDate: nil)
        XCTAssertEqual(out.profile.rungs[Ladder.push.rawValue], 0)
    }

    func testAMarginalMissDoesNotStepBack() {
        var p = bodyweightProfile()
        p.rungs[Ladder.push.rawValue] = 1
        let r = T.range("knee_pushup", p)
        let miss = { (offset: Int) in
            T.session(on: T.day(offset), logs: [T.log("knee_pushup", sets: [(r.min - 1, 0), (r.min - 1, 0)], min: r.min, max: r.max)])
        }
        let history = [miss(-6), miss(-3), miss(0)]
        XCTAssertEqual(AdaptiveEngine.apply(session: history[2], to: p, history: history, previousSessionDate: nil).profile.rungs[Ladder.push.rawValue], 1)
    }

    // MARK: Level, gaps and deloads through apply()

    func testLevelCooldownAppliesThroughApply() {
        var p = T.profile(level: .beginner)
        p.intensity = 3
        p.startDate = T.day(-10)                          // level is only 10 days old
        let earlier = T.session(on: T.day(-3), logs: [], feedback: .tooEasy, planned: 10, done: 10)
        let s = T.session(on: T.day(0), logs: [], feedback: .tooEasy, planned: 10, done: 10)
        let out = AdaptiveEngine.apply(session: s, to: p, history: [earlier, s], previousSessionDate: earlier.date)
        XCTAssertEqual(out.profile.level, .beginner)
        p.startDate = T.day(-60)
        let later = AdaptiveEngine.apply(session: s, to: p, history: [earlier, s], previousSessionDate: earlier.date)
        XCTAssertEqual(later.profile.level, .intermediate)
        XCTAssertNotNil(later.profile.levelChangedAt)
    }

    func testAGapOfTwoWeeksRestartsTheBlock() {
        var p = T.profile(level: .intermediate)
        p.blockStart = T.week(-10)
        let s = T.session(on: T.week(2), logs: [])
        let out = AdaptiveEngine.apply(session: s, to: p, history: [s], previousSessionDate: T.day(0))
        XCTAssertEqual(out.profile.blockStart, TrainingCalendar.weekStart(of: T.week(2)))
        XCTAssertTrue(out.messages.contains { $0.contains("Welcome back") })
    }

    func testFatigueStartsADeloadForTheRestOfTheWeek() {
        var p = T.profile(level: .intermediate)
        p.startDate = T.day(-80)
        let base = (1...3).map { T.session(on: T.day(-40 - $0), logs: []) }
        let hard = { (offset: Int) in
            T.session(on: T.day(offset), logs: [T.log("db_bench", sets: [(3, 20), (3, 20), (2, 20)], min: 8, max: 12)],
                      feedback: .tooHard, planned: 10, done: 6)
        }
        let history = base + [hard(-3), hard(-1)]
        let out = AdaptiveEngine.apply(session: history.last!, to: p, history: history, previousSessionDate: T.day(-3))
        XCTAssertEqual(out.profile.deloadWeekStart, TrainingCalendar.weekStart(of: T.day(-1)))
        XCTAssertTrue(out.messages.contains { $0.lowercased().contains("deload") })
        // The block restarts the week after.
        XCTAssertEqual(out.profile.blockStart, TrainingCalendar.calendar.date(byAdding: .day, value: 7, to: TrainingCalendar.weekStart(of: T.day(-1))))
    }
}

final class VolumeTests: XCTestCase {
    func testTargetsGrowWithLevelAndScaleWithGoal() {
        for muscle in VolumePlanner.muscles {
            let b = VolumePlanner.target(for: muscle, level: .beginner, goal: .buildMuscle)
            let i = VolumePlanner.target(for: muscle, level: .intermediate, goal: .buildMuscle)
            let a = VolumePlanner.target(for: muscle, level: .advanced, goal: .buildMuscle)
            XCTAssertLessThanOrEqual(b.high, i.high, "\(muscle)")
            XCTAssertLessThanOrEqual(i.high, a.high, "\(muscle)")
            XCTAssertLessThan(VolumePlanner.target(for: muscle, level: .intermediate, goal: .stayFit).high, i.high, "\(muscle)")
        }
    }

    func testCompletedSetsCountByMuscleWithinTheWeek() {
        let logs = [T.log("db_bench", sets: [(8, 20), (8, 20), (8, 20)], min: 6, max: 10), T.log("plank", sets: [(30, 0), (30, 0)], min: 20, max: 45, seconds: true)]
        let inWeek = T.session(on: T.day(1), logs: logs)
        let otherWeek = T.session(on: T.day(9), logs: logs)
        let sets = VolumePlanner.completedSets(in: [inWeek, otherWeek], weekContaining: T.day(2))
        XCTAssertEqual(sets[.chest], 3)
        XCTAssertEqual(sets[.core], 2)
    }
}
