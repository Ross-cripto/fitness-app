import Foundation

/// How one exercise has improved over time (chart in the exercise sheet).
enum ExerciseProgress {
    enum Metric {
        /// Weighted lifts: estimated one-rep max from the best set (Epley).
        case oneRepMax
        /// Bodyweight moves: reps in the best set.
        case reps
        /// Holds: seconds in the longest set.
        case seconds
    }

    struct Point: Identifiable, Equatable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    static func metric(for exercise: Exercise) -> Metric {
        if exercise.kind == .timed { return .seconds }
        return exercise.isLoaded ? .oneRepMax : .reps
    }

    /// One point per session that trained the exercise, oldest first.
    static func series(exerciseID: String, sessions: [WorkoutSession]) -> [Point] {
        guard let exercise = ExerciseLibrary.byID[exerciseID] else { return [] }
        let metric = metric(for: exercise)
        var points: [Point] = []
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            var best: Double?
            for log in session.logs where log.exerciseID == exerciseID {
                for set in log.sets {
                    let value: Double?
                    switch metric {
                    case .oneRepMax: value = Progression.estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps)
                    case .reps: value = set.reps > 0 ? Double(set.reps) : nil
                    case .seconds: value = set.seconds > 0 ? Double(set.seconds) : nil
                    }
                    if let value { best = max(best ?? 0, value) }
                }
            }
            if let best { points.append(Point(date: session.date, value: best)) }
        }
        return points
    }

    /// Change from the first to the last point (nil with fewer than two).
    static func change(_ points: [Point]) -> Double? {
        guard points.count >= 2, let first = points.first, let last = points.last else { return nil }
        return last.value - first.value
    }
}
