import Foundation

/// Movement patterns. The planner picks exercises by pattern, not by muscle name.
enum Pattern: String, Codable, CaseIterable {
    case squat, lunge, hinge, calves
    case horizontalPush, verticalPush, chestIsolation, shoulderIsolation, rearDelt
    case horizontalPull, verticalPull
    case biceps, triceps
    case coreStability, coreFlexion, coreRotation
    case cardio, fullBody, mobility

    /// The muscle group whose weekly volume this pattern counts toward.
    var muscle: MuscleGroup {
        switch self {
        case .squat, .lunge, .hinge, .calves: return .legs
        case .horizontalPush, .chestIsolation: return .chest
        case .verticalPush, .shoulderIsolation, .rearDelt: return .shoulders
        case .horizontalPull, .verticalPull: return .back
        case .biceps, .triceps: return .arms
        case .coreStability, .coreFlexion, .coreRotation: return .core
        case .cardio: return .cardio
        case .fullBody: return .fullBody
        case .mobility: return .mobility
        }
    }

    /// Patterns to try, in order, when nothing is available for this one. Fallbacks stay in the same muscle
    /// group so weekly volume bookkeeping stays honest.
    var fallbacks: [Pattern] {
        switch self {
        case .verticalPull: return [.horizontalPull]
        case .chestIsolation: return [.horizontalPush]
        case .squat: return [.lunge]
        case .lunge: return [.squat]
        case .calves: return [.squat]
        case .shoulderIsolation: return [.verticalPush]
        case .rearDelt: return []
        case .coreRotation: return [.coreFlexion]
        case .coreFlexion: return [.coreStability]
        case .coreStability: return [.coreFlexion]
        default: return []
        }
    }

    /// The bodyweight progression ladder this pattern advances along, if any.
    var ladder: Ladder? {
        switch self {
        case .horizontalPush: return .push
        case .verticalPush: return .verticalPush
        case .horizontalPull, .verticalPull: return .pull
        case .squat: return .squat
        case .lunge: return .lunge
        case .hinge: return .hinge
        case .triceps: return .triceps
        case .coreStability: return .coreStability
        case .coreFlexion: return .coreFlexion
        default: return nil
        }
    }
}

/// Bodyweight progressions, easiest rung first. See `ExerciseMetaTable` for the members.
enum Ladder: String, Codable, CaseIterable {
    case push, verticalPush, pull, squat, lunge, hinge, triceps, coreStability, coreFlexion

    var title: String {
        switch self {
        case .push: return L("Push")
        case .verticalPush: return L("Shoulder press")
        case .pull: return L("Pull")
        case .squat: return L("Squat")
        case .lunge: return L("Lunge")
        case .hinge: return L("Hip hinge")
        case .triceps: return L("Triceps")
        case .coreStability: return L("Core stability")
        case .coreFlexion: return L("Core strength")
        }
    }
}

struct ExerciseMeta {
    var pattern: Pattern
    /// Multi-joint lift (heavier, longer rest, counts first for progression).
    var isCompound: Bool
    /// Body areas this exercise loads enough to be excluded when the person protects them.
    var stress: [BodyArea]
    var isImpact: Bool
    /// Position on a bodyweight ladder.
    var ladder: Ladder?
    var rung: Int
    /// Lower is chosen first among similar options.
    var priority: Int
}

/// Movement pattern, joint stress and progression ladder position of every exercise (from `data/exercises.json`).
enum ExerciseMetaTable {
    static let fallback = ExerciseMeta(pattern: .fullBody, isCompound: false, stress: [], isImpact: false,
                                       ladder: nil, rung: 0, priority: 9)

    static func meta(_ id: String) -> ExerciseMeta { table[id] ?? fallback }

    static let table: [String: ExerciseMeta] = {
        var t: [String: ExerciseMeta] = [:]
        for record in ExerciseLibrary.records { t[record.id] = record.meta }
        return t
    }()

    /// Exercises that hang from something. A pull-up bar (or a gym) is enough to plan them.
    static let needsPullUpBar: Set<String> = ["pullup"]

    /// Ladder members grouped by rung (ids sorted so results are deterministic).
    static let ladders: [Ladder: [Int: [String]]] = {
        var result: [Ladder: [Int: [String]]] = [:]
        for (id, meta) in table {
            guard let ladder = meta.ladder else { continue }
            result[ladder, default: [:]][meta.rung, default: []].append(id)
        }
        for ladder in result.keys {
            for rung in result[ladder]!.keys { result[ladder]![rung]!.sort() }
        }
        return result
    }()

    static func maxRung(_ ladder: Ladder) -> Int {
        ladders[ladder]?.keys.max() ?? 0
    }
}

extension Exercise {
    var meta: ExerciseMeta { ExerciseMetaTable.meta(id) }
    var pattern: Pattern { meta.pattern }
    var isCompound: Bool { meta.isCompound }
    var isBodyweightLadderMember: Bool { meta.ladder != nil }
}
