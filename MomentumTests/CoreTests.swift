import XCTest
@testable import Momentum

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
        XCTAssertEqual(abs(Motion.blend(a, b, 0.5)[2]), 180, accuracy: 0.001)
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

    func testNothingSinksBelowTheFloorMidMotion() {
        // Animations stay inside their drawing bounds even between keyframes (feet never cut off).
        for (id, motion) in MotionLibrary.all {
            let n = motion.frames.count
            for i in 0..<n {
                for step in 0...10 {
                    let pose = Motion.blend(motion.frames[i], motion.frames[(i + 1) % n], Double(step) / 10)
                    let j = Skeleton.joints(pose, front: motion.isFront)
                    let ys = [j.ankleNear.y, j.ankleFar.y, j.toeNear.y, j.toeFar.y, j.wristNear.y, j.head.y - Body.headRadius]
                    XCTAssertGreaterThanOrEqual(ys.min()! + 0.001, motion.bounds[2], "\(id) frame \(i) step \(step)")
                }
            }
        }
    }
}

final class LinksAndPersistenceTests: XCTestCase {
    func testEveryExerciseHasAYouTubeLink() {
        for exercise in ExerciseLibrary.all {
            let url = exercise.videoURL
            XCTAssertEqual(url.host, "www.youtube.com", exercise.id)
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "search_query" }?.value
            XCTAssertEqual(query, "\(exercise.name) proper form tutorial", exercise.id)
        }
    }

    func testProfileFromOlderVersionStillDecodes() throws {
        // A save file written before most current fields existed.
        let json = #"{"name":"Sam","level":"intermediate","onboarded":true,"sessionMinutes":40}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.name, "Sam")
        XCTAssertEqual(profile.level, .intermediate)
        XCTAssertEqual(profile.sessionMinutes, 40)
        XCTAssertTrue(profile.onboarded)
        XCTAssertFalse(profile.healthSync)
        XCTAssertTrue(profile.limitations.isEmpty)
        XCTAssertTrue(profile.rungs.isEmpty)
    }

    func testUnknownEnumValuesFallBackInsteadOfLosingTheProfile() throws {
        let json = #"{"name":"Sam","goal":"someFutureGoal","level":"advanced"}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.level, .advanced)
        XCTAssertEqual(profile.goal, UserProfile().goal)
    }

    func testProfileRoundTrips() throws {
        var profile = UserProfile()
        profile.healthSync = true
        profile.goal = .getStronger
        profile.weightKg = 82.5
        profile.limitations = [.knees, .wrists]
        profile.trainingWeekdays = [2, 4, 6]
        profile.rungs = ["push": 2]
        profile.swapPreferences = ["bench_press": "db_bench"]
        profile.check = FitnessCheck(pushups: 12, squats: nil, plankSeconds: 40, pullups: 1)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UserProfile.self, from: try encoder.encode(profile))
        XCTAssertEqual(decoded.limitations, profile.limitations)
        XCTAssertEqual(decoded.trainingWeekdays, profile.trainingWeekdays)
        XCTAssertEqual(decoded.rungs, profile.rungs)
        XCTAssertEqual(decoded.swapPreferences, profile.swapPreferences)
        XCTAssertEqual(decoded.check, profile.check)
        XCTAssertEqual(decoded.goal, .getStronger)
        XCTAssertEqual(decoded.weightKg, 82.5)
    }

    func testSessionLogsFromOlderVersionsDecode() throws {
        let json = #"{"exerciseID":"pushup","targetSets":3,"target":10,"sets":[{"reps":10,"weightKg":0,"seconds":0}],"id":"6F1C8D3E-1234-4B6A-9C2F-0A1B2C3D4E5F"}"#
        let log = try JSONDecoder().decode(ExerciseLog.self, from: Data(json.utf8))
        XCTAssertNil(log.repMin)
        XCTAssertNil(log.effort)
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

    func testWorkoutTimeAndCaloriesAreSane() {
        let p = PlannedExercise(exerciseID: "db_bench", sets: 3, target: 10, repMin: 6, repMax: 10, restSeconds: 90, weightKg: 20)
        let w = Workout(id: "w", title: "t", subtitle: "s", theme: .chest, exercises: [p, p])
        XCTAssertGreaterThan(w.minutes, 5)
        XCTAssertGreaterThan(w.calories(weightKg: 80), 20)
        XCTAssertEqual(p.targetLabel, "3 × 6-10")
    }
}
