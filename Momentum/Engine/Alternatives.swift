import Foundation

/// Why someone wants a different exercise. Each reason produces different suggestions.
enum SwapReason: String, CaseIterable, Identifiable {
    case tooHard, tooEasy, pain, noEquipment, dislike

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tooHard: return "Too hard for me"
        case .tooEasy: return "Too easy"
        case .pain: return "It hurts or feels wrong"
        case .noEquipment: return "I don't have the equipment"
        case .dislike: return "I just don't like it"
        }
    }

    var symbol: String {
        switch self {
        case .tooHard: return "arrow.down.circle.fill"
        case .tooEasy: return "arrow.up.circle.fill"
        case .pain: return "bandage.fill"
        case .noEquipment: return "dumbbell"
        case .dislike: return "hand.thumbsdown.fill"
        }
    }
}

/// How the suggestion compares with the exercise being replaced.
enum Relation: String {
    case easier, similar, harder

    var title: String {
        switch self {
        case .easier: return "Easier"
        case .similar: return "Similar"
        case .harder: return "Harder"
        }
    }
}

/// How long a swap should last.
enum SwapScope: String, CaseIterable, Identifiable {
    case today, always, neverShowOriginal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Just this workout"
        case .always: return "Use this from now on"
        case .neverShowOriginal: return "Never show the original again"
        }
    }
}

struct Alternative: Identifiable, Equatable {
    var exercise: Exercise
    var relation: Relation
    var why: String

    var id: String { exercise.id }
}

extension Exercise {
    /// Rough difficulty for comparing two exercises of the same kind. Higher = harder.
    /// Bodyweight moves use the ladder rung and level; loaded lifts use how demanding the equipment is
    /// (barbell > dumbbell > machine or cable), because the load itself can always be changed.
    var difficulty: Double {
        var value = Double(level.rank) * 1.5 + Double(meta.rung) * 0.5
        if isLoaded {
            if Progression.barbellIDs.contains(id) {
                value += 3
            } else if equipment == .fullGym {
                value += 1
            } else {
                value += 2
            }
        }
        return value
    }
}

enum Alternatives {
    private static func relation(from current: Exercise, to candidate: Exercise, reason: SwapReason) -> Relation {
        func compare(_ delta: Double) -> Relation { delta < -0.25 ? .easier : (delta > 0.25 ? .harder : .similar) }
        switch (current.isLoaded, candidate.isLoaded) {
        case (true, true), (false, false):
            return compare(candidate.difficulty - current.difficulty)
        case (true, false):
            // Dropping the weight: the bodyweight version is the gentler option.
            return .easier
        case (false, true):
            // Adding weight makes a bodyweight movement harder when you want more challenge.
            return reason == .tooEasy ? .harder : .similar
        }
    }

    /// Suggested replacements for `planned`, best first.
    ///
    /// - Parameters:
    ///   - painAreas: for `.pain`: the body areas involved. Empty means "whatever this exercise stresses".
    static func suggest(
        for planned: PlannedExercise,
        in workout: Workout,
        reason: SwapReason,
        profile: UserProfile,
        painAreas: [BodyArea] = [],
        limit: Int = 6
    ) -> [Alternative] {
        let current = planned.exercise
        let usedIDs = Set(workout.exercises.map { $0.exerciseID } + workout.warmup.map { $0.exerciseID })
        let avoided: Set<BodyArea> = reason == .pain
            ? Set(painAreas.isEmpty ? current.meta.stress : painAreas)
            : []
        let avoidImpact = reason == .pain && avoided.contains(.knees)

        var scored: [(score: Double, samePattern: Bool, alternative: Alternative)] = []
        for candidate in ExerciseLibrary.all {
            guard candidate.id != current.id, !usedIDs.contains(candidate.id) else { continue }
            guard PlanGenerator.isAllowed(candidate, profile: profile) else { continue }
            // Keep bodyweight ladders sensible: never offer something far above the person's rung.
            if let ladder = candidate.meta.ladder, !candidate.isLoaded,
               candidate.meta.rung > PlanGenerator.rung(ladder, profile: profile) + (reason == .tooEasy ? 1 : 0) {
                continue
            }
            if candidate.isLoaded && candidate.level.rank > profile.level.rank + (reason == .tooEasy ? 1 : 0) { continue }
            if !avoided.isEmpty && candidate.meta.stress.contains(where: { avoided.contains($0) }) { continue }
            if avoidImpact && candidate.meta.isImpact { continue }

            let samePattern = candidate.pattern == current.pattern
            guard samePattern || candidate.muscle == current.muscle else { continue }
            // A compound lift is never replaced by an isolation move (or the reverse) unless it's the same movement.
            if !samePattern && candidate.isCompound != current.isCompound { continue }
            // Warm-up drills and cardio are never a swap for a strength exercise.
            if candidate.muscle == .mobility || (candidate.muscle == .cardio) != (current.muscle == .cardio) { continue }

            let relation = self.relation(from: current, to: candidate, reason: reason)
            switch reason {
            case .tooHard where relation == .harder: continue
            case .tooEasy where relation == .easier: continue
            case .noEquipment where candidate.equipment.rank >= current.equipment.rank: continue
            default: break
            }

            var score = samePattern ? 100.0 : 40.0
            switch reason {
            case .tooHard:
                // The smallest step down first, so the exercise stays as close to the original as possible.
                score += relation == .easier ? 30 - min(15, abs(candidate.difficulty - current.difficulty)) : 5
            case .tooEasy:
                score += relation == .harder ? 30 - min(15, abs(candidate.difficulty - current.difficulty)) : 5
            case .noEquipment:
                // Closest equipment first (barbell -> dumbbells before bodyweight).
                score += candidate.equipment.rank == current.equipment.rank - 1 ? 14 : 6
            case .pain, .dislike:
                score += 10 - min(8, abs(candidate.difficulty - current.difficulty))
            }
            score -= Double(candidate.meta.priority) * 0.1

            scored.append((score, samePattern,
                           Alternative(exercise: candidate, relation: relation,
                                       why: explain(candidate, current, reason, relation, avoided))))
        }

        var ranked = scored.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.alternative.exercise.name < b.alternative.exercise.name
        }
        // Prefer the same movement pattern. Other patterns only fill in when there are too few.
        if ranked.filter({ $0.samePattern }).count >= 3 { ranked = ranked.filter { $0.samePattern } }
        return ranked.prefix(limit).map { $0.alternative }
    }

    private static func explain(
        _ candidate: Exercise,
        _ current: Exercise,
        _ reason: SwapReason,
        _ relation: Relation,
        _ avoided: Set<BodyArea>
    ) -> String {
        switch reason {
        case .tooHard:
            if candidate.isLoaded == false && current.isLoaded { return "Bodyweight version, no weight to manage." }
            return relation == .easier ? "A gentler version of the same movement." : "Same movement, and you can start light."
        case .tooEasy:
            return relation == .harder ? "A harder variation of the same movement." : "Same movement, so you can add weight."
        case .pain:
            let areas = avoided.map { $0.title.lowercased() }.sorted().joined(separator: " and ")
            return areas.isEmpty ? "Puts less stress on the joints involved." : "Doesn't load your \(areas)."
        case .noEquipment:
            return candidate.equipment == .bodyweight
                ? "No equipment needed."
                : "Needs only \(candidate.equipment.title.lowercased())."
        case .dislike:
            return candidate.pattern == current.pattern
                ? "Trains the same movement."
                : "Works the same muscles (\(candidate.muscle.title.lowercased()))."
        }
    }
}

extension UserProfile {
    /// Remember how a swap should be treated in future plans.
    mutating func applySwap(
        original: Exercise,
        replacement: Exercise,
        scope: SwapScope,
        protecting areas: [BodyArea] = []
    ) {
        switch scope {
        case .today:
            break
        case .always:
            swapPreferences[original.id] = replacement.id
        case .neverShowOriginal:
            if !excludedExercises.contains(original.id) { excludedExercises.append(original.id) }
            swapPreferences[original.id] = replacement.id
        }
        for area in areas where !limitations.contains(area) { limitations.append(area) }
    }
}
