import XCTest
@testable import Momentum

final class ExerciseProgressTests: EnglishTestCase {
    func testWeightedLiftsUseEstimatedOneRepMaxOfTheBestSet() {
        let sessions = [
            T.session(on: T.day(0), logs: [T.log("db_bench", sets: [(10, 20), (8, 22.5)], min: 8, max: 12)]),
            T.session(on: T.day(7), logs: [T.log("db_bench", sets: [(10, 22.5)], min: 8, max: 12)]),
        ]
        let points = ExerciseProgress.series(exerciseID: "db_bench", sessions: sessions)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].value, 22.5 * (1 + 8.0 / 30), accuracy: 0.001)   // 8 x 22.5 beats 10 x 20
        XCTAssertEqual(points[1].value, 22.5 * (1 + 10.0 / 30), accuracy: 0.001)
        XCTAssertGreaterThan(ExerciseProgress.change(points) ?? 0, 0)
    }

    func testBodyweightUsesRepsAndHoldsUseSeconds() {
        let reps = ExerciseProgress.series(exerciseID: "pushup", sessions: [
            T.session(on: T.day(0), logs: [T.log("pushup", sets: [(8, 0), (10, 0)], min: 8, max: 15)]),
            T.session(on: T.day(7), logs: [T.log("pushup", sets: [(12, 0)], min: 8, max: 15)]),
        ])
        XCTAssertEqual(reps.map(\.value), [10, 12])
        XCTAssertEqual(ExerciseProgress.metric(for: ExerciseLibrary.exercise("plank")), .seconds)
        let holds = ExerciseProgress.series(exerciseID: "plank", sessions: [
            T.session(on: T.day(0), logs: [T.log("plank", sets: [(30, 0)], min: 20, max: 45, seconds: true)]),
        ])
        XCTAssertEqual(holds.count, 1)
    }

    func testOrderedByDateAndSkipsOtherExercisesAndEmptySets() {
        let sessions = [
            T.session(on: T.day(7), logs: [T.log("pushup", sets: [(12, 0)], min: 8, max: 15)]),
            T.session(on: T.day(3), logs: [T.log("bw_squat", sets: [(20, 0)], min: 10, max: 20)]),
            T.session(on: T.day(0), logs: [T.log("pushup", sets: [(9, 0)], min: 8, max: 15)]),
        ]
        let points = ExerciseProgress.series(exerciseID: "pushup", sessions: sessions)
        XCTAssertEqual(points.map(\.value), [9, 12])
        XCTAssertNil(ExerciseProgress.change([points[0]]))
        XCTAssertTrue(ExerciseProgress.series(exerciseID: "unknown_id", sessions: sessions).isEmpty)
    }
}
