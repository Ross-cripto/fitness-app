import Foundation

/// Adjusts difficulty from how workouts actually go.
///
/// `intensity` is a small integer offset (-3...+3) applied to sets, reps, hold
/// times and rest. When it runs off either end, the user's level itself moves.
enum AdaptiveEngine {
    static let maxIntensity = 3

    struct Outcome: Equatable {
        var level: FitnessLevel
        var intensity: Int
        var message: String?
    }

    static func evaluate(
        level: FitnessLevel,
        intensity: Int,
        feedback: WorkoutFeedback,
        completion: Double
    ) -> Outcome {
        var delta: Int
        switch feedback {
        case .tooEasy: delta = 1
        case .justRight: delta = 0
        case .tooHard: delta = -1
        }
        // Bailing on most of the session means it was too much, whatever they tapped.
        if completion < 0.6 { delta = min(delta, -1) }

        var newLevel = level
        var newIntensity = intensity + delta
        var message: String?

        if newIntensity > maxIntensity {
            if level != .advanced {
                newLevel = FitnessLevel.from(rank: level.rank + 1)
                newIntensity = 0
                message = "You're outgrowing this plan. Moved up to \(newLevel.title)."
            } else {
                newIntensity = maxIntensity
                message = "You're already at the top. Nice work."
            }
        } else if newIntensity < -maxIntensity {
            if level != .beginner {
                newLevel = FitnessLevel.from(rank: level.rank - 1)
                newIntensity = 0
                message = "Let's rebuild. Moved down to \(newLevel.title) so training stays sustainable."
            } else {
                newIntensity = -maxIntensity
                message = "Taking it easy. Consistency beats intensity."
            }
        } else if delta > 0 {
            message = "Great. Your next workouts will be a bit tougher."
        } else if delta < 0 {
            message = "Got it. Your next workouts will be a notch easier."
        }

        return Outcome(level: newLevel, intensity: newIntensity, message: message)
    }

    /// Intensity used for planning. After a long break we ease the user back in.
    static func effectiveIntensity(profile: UserProfile, history: [WorkoutSession], now: Date = Date()) -> Int {
        guard let last = history.map({ $0.date }).max() else { return profile.intensity }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: last),
            to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days >= 21 { return min(profile.intensity, -2) }
        if days >= 10 { return min(profile.intensity, -1) }
        return profile.intensity
    }
}

/// Progressive overload for weighted exercises.
enum WeightAdvisor {
    static func suggest(for exercise: Exercise, profile: UserProfile, history: [WorkoutSession]) -> Double? {
        guard let ratio = exercise.loadRatio else { return nil }

        if let last = lastLog(for: exercise.id, in: history),
           let top = last.sets.map({ $0.weightKg }).max(), top > 0 {
            let allSetsDone = last.sets.count >= last.targetSets
            let hitEveryRep = last.sets.allSatisfy { $0.reps >= last.target }
            let totalReps = last.sets.reduce(0) { $0 + $1.reps }
            let averageReps = Double(totalReps) / Double(max(1, last.sets.count))

            if allSetsDone && hitEveryRep {
                return roundLoad(top + increment(after: top))
            }
            if averageReps < 0.7 * Double(last.target) {
                return roundLoad(top * 0.95)
            }
            return top
        }

        let estimate = ratio * profile.weightKg * profile.level.weightFactor
        return roundLoad(max(estimate, 2))
    }

    static func lastLog(for exerciseID: String, in history: [WorkoutSession]) -> ExerciseLog? {
        for session in history.sorted(by: { $0.date > $1.date }) {
            if let log = session.logs.first(where: { $0.exerciseID == exerciseID && !$0.sets.isEmpty }) {
                return log
            }
        }
        return nil
    }

    static func increment(after weight: Double) -> Double {
        if weight < 10 { return 0.5 }
        if weight < 20 { return 1 }
        return 2.5
    }

    static func roundLoad(_ value: Double) -> Double {
        let step: Double
        if value < 10 { step = 0.5 } else if value < 20 { step = 1 } else { step = 2.5 }
        return max(step, (value / step).rounded() * step)
    }
}
