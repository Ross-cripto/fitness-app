import Foundation

/// Everything that changes about a person's plan after a workout is saved.
struct SessionOutcome {
    var profile: UserProfile
    /// Plain-language notes for the person ("Push: moving up to Push-Up", "Deload started"...).
    var messages: [String]
}

enum AdaptiveEngine {
    static let maxIntensity = 3

    struct Outcome: Equatable {
        var level: FitnessLevel
        var intensity: Int
        var message: String?
    }

    // MARK: Session feedback -> difficulty offset and level

    /// - Parameters:
    ///   - previousFeedback: how the previous session was rated. A change needs two agreeing ratings in a row,
    ///     so one odd day does not move the plan. Finishing under 60% of the sets counts immediately.
    ///   - canChangeLevel: level moves at most once every four weeks.
    static func evaluate(
        level: FitnessLevel,
        intensity: Int,
        feedback: WorkoutFeedback,
        completion: Double,
        previousFeedback: WorkoutFeedback? = nil,
        canChangeLevel: Bool = true
    ) -> Outcome {
        var delta = 0
        if completion < 0.6 {
            delta = -1
        } else if feedback == .tooEasy && previousFeedback == .tooEasy {
            delta = 1
        } else if feedback == .tooHard && previousFeedback == .tooHard {
            delta = -1
        }

        var newLevel = level
        var newIntensity = intensity + delta
        var message: String?

        if newIntensity > maxIntensity {
            if level != .advanced && canChangeLevel {
                newLevel = FitnessLevel.from(rank: level.rank + 1)
                newIntensity = 0
                message = "You're outgrowing this plan. Moved up to \(newLevel.title)."
            } else {
                newIntensity = maxIntensity
            }
        } else if newIntensity < -maxIntensity {
            if level != .beginner && canChangeLevel {
                newLevel = FitnessLevel.from(rank: level.rank - 1)
                newIntensity = 0
                message = "Let's rebuild. Moved down to \(newLevel.title) so training stays sustainable."
            } else {
                newIntensity = -maxIntensity
            }
        } else if delta > 0 {
            message = "Your last two sessions felt easy, so upcoming workouts get a bit tougher."
        } else if delta < 0 {
            message = "Your recent sessions were hard, so upcoming workouts get a notch easier."
        }

        return Outcome(level: newLevel, intensity: newIntensity, message: message)
    }

    // MARK: Applying a finished session

    /// - Parameters:
    ///   - history: all sessions **including** `session`.
    ///   - previousSessionDate: the date of the session before this one, if any.
    static func apply(
        session: WorkoutSession,
        to profile: UserProfile,
        history: [WorkoutSession],
        previousSessionDate: Date?
    ) -> SessionOutcome {
        var p = profile
        var messages: [String] = []
        let earlier = history.filter { $0.id != session.id }

        // 1. Overall difficulty and level from how the session felt.
        if let feedback = session.feedback {
            let previousFeedback = earlier.sorted { $0.date > $1.date }.first?.feedback
            let sinceLevelChange = TrainingCalendar.daysBetween(p.levelChangedAt ?? p.startDate, session.date)
            let outcome = evaluate(
                level: p.level, intensity: p.intensity, feedback: feedback, completion: session.completion,
                previousFeedback: previousFeedback, canChangeLevel: sinceLevelChange >= 28
            )
            if outcome.level != p.level { p.levelChangedAt = session.date }
            p.level = outcome.level
            p.intensity = outcome.intensity
            if let message = outcome.message { messages.append(message) }
        }

        // 2. Bodyweight ladders: move up when the top of the range is reached, back down after two misses.
        for log in session.logs {
            let exercise = ExerciseLibrary.exercise(log.exerciseID)
            guard let ladder = exercise.meta.ladder else { continue }
            let rung = exercise.meta.rung
            let current = PlanGenerator.rung(ladder, profile: p)
            let range = Progression.repRange(for: exercise, goal: p.goal, level: p.level)
            // One rung change per ladder every two weeks, so a hard week can't cause back-and-forth.
            let recentlyChanged = p.rungChangedAt[ladder.rawValue].map {
                TrainingCalendar.daysBetween($0, session.date) < 14
            } ?? false
            if recentlyChanged { continue }

            if Progression.reachedTop(log, exercise: exercise, range: range), rung >= current,
               current < ExerciseMetaTable.maxRung(ladder),
               let next = nextRungExercise(ladder: ladder, rung: current + 1, profile: p) {
                p.rungs[ladder.rawValue] = current + 1
                p.rungChangedAt[ladder.rawValue] = session.date
                messages.append("\(ladder.title): moving up to \(next.name).")
            } else if rung == current, current > 0,
                      Progression.failed(log, exercise: exercise, range: range, tolerance: 3),
                      case let recent = Progression.recentLogs(for: exercise.id, in: earlier, limit: 2),
                      recent.count == 2,
                      recent.allSatisfy({ Progression.failed($0, exercise: exercise, range: range, tolerance: 3) }) {
                p.rungs[ladder.rawValue] = current - 1
                p.rungChangedAt[ladder.rawValue] = session.date
                messages.append("\(ladder.title): stepping back to an easier variation so you can build up again.")
            }
        }

        // 3. A long gap restarts the block.
        if let previous = previousSessionDate, TrainingCalendar.daysBetween(previous, session.date) >= 14 {
            p.blockStart = TrainingCalendar.weekStart(of: session.date)
            p.deloadWeekStart = nil
            messages.append("Welcome back. A fresh training block starts this week.")
        }

        // 4. Accumulated fatigue turns the rest of the week into a deload.
        let phase = Periodization.phase(on: session.date, profile: p, history: history, now: session.date)
        if Recovery.shouldDeload(profile: p, history: history, phase: phase, now: session.date) {
            let weekStart = TrainingCalendar.weekStart(of: session.date)
            p.deloadWeekStart = weekStart
            p.blockStart = TrainingCalendar.calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            messages.append("You've been under a lot of strain. The rest of this week is a lighter deload, then a fresh block.")
        }

        return SessionOutcome(profile: p, messages: messages)
    }

    /// The first allowed exercise on a rung (used to name what the person is moving up to).
    static func nextRungExercise(ladder: Ladder, rung: Int, profile: UserProfile) -> Exercise? {
        let ids = ExerciseMetaTable.ladders[ladder]?[rung] ?? []
        return ids
            .map { ExerciseLibrary.exercise($0) }
            .first { PlanGenerator.isAllowed($0, profile: profile) }
    }
}
