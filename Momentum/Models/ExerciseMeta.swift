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
        case .push: return "Push"
        case .verticalPush: return "Shoulder press"
        case .pull: return "Pull"
        case .squat: return "Squat"
        case .lunge: return "Lunge"
        case .hinge: return "Hip hinge"
        case .triceps: return "Triceps"
        case .coreStability: return "Core stability"
        case .coreFlexion: return "Core strength"
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

enum ExerciseMetaTable {
    private static func m(
        _ pattern: Pattern,
        compound: Bool = true,
        stress: [BodyArea] = [],
        impact: Bool = false,
        ladder: Ladder? = nil,
        rung: Int = 0,
        priority: Int = 5
    ) -> ExerciseMeta {
        ExerciseMeta(pattern: pattern, isCompound: compound, stress: stress, isImpact: impact,
                     ladder: ladder, rung: rung, priority: priority)
    }

    static let fallback = ExerciseMeta(pattern: .fullBody, isCompound: false, stress: [], isImpact: false,
                                       ladder: nil, rung: 0, priority: 9)

    static func meta(_ id: String) -> ExerciseMeta { table[id] ?? fallback }

    static let table: [String: ExerciseMeta] = {
        var t: [String: ExerciseMeta] = [:]

        // Legs
        t["bw_squat"] = m(.squat, ladder: .squat, rung: 0, priority: 1)
        t["wall_sit"] = m(.squat, compound: false, ladder: .squat, rung: 0, priority: 2)
        t["jump_squat"] = m(.squat, stress: [.knees], impact: true, ladder: .squat, rung: 1)
        t["goblet_squat"] = m(.squat, priority: 3)
        t["leg_press"] = m(.squat, priority: 2)
        t["back_squat"] = m(.squat, stress: [.knees, .lowerBack], priority: 1)
        t["reverse_lunge"] = m(.lunge, stress: [.knees], ladder: .lunge, rung: 0)
        t["split_squat"] = m(.lunge, stress: [.knees], ladder: .lunge, rung: 1)
        t["db_lunge"] = m(.lunge, stress: [.knees], priority: 1)
        t["glute_bridge"] = m(.hinge, ladder: .hinge, rung: 0)
        t["single_leg_bridge"] = m(.hinge, ladder: .hinge, rung: 1)
        t["db_rdl"] = m(.hinge, stress: [.lowerBack], priority: 2)
        t["deadlift"] = m(.hinge, stress: [.lowerBack], priority: 1)
        t["calf_raise"] = m(.calves, compound: false)

        // Chest
        t["wall_pushup"] = m(.horizontalPush, ladder: .push, rung: 0)
        t["knee_pushup"] = m(.horizontalPush, stress: [.wrists], ladder: .push, rung: 1)
        t["pushup"] = m(.horizontalPush, stress: [.wrists], ladder: .push, rung: 2)
        t["decline_pushup"] = m(.horizontalPush, stress: [.wrists, .shoulders], ladder: .push, rung: 3)
        t["bench_press"] = m(.horizontalPush, priority: 1)
        t["db_bench"] = m(.horizontalPush, priority: 2)
        t["machine_chest_press"] = m(.horizontalPush, priority: 3)
        t["db_incline_press"] = m(.horizontalPush, priority: 4)
        t["db_fly"] = m(.chestIsolation, compound: false, stress: [.shoulders])

        // Back
        t["superman"] = m(.horizontalPull, compound: false, stress: [.lowerBack], ladder: .pull, rung: 0)
        t["reverse_snow_angel"] = m(.horizontalPull, compound: false, stress: [.lowerBack], ladder: .pull, rung: 0)
        t["inverted_row"] = m(.horizontalPull, ladder: .pull, rung: 1)
        t["pullup"] = m(.verticalPull, stress: [.shoulders], ladder: .pull, rung: 2, priority: 1)
        t["barbell_row"] = m(.horizontalPull, stress: [.lowerBack], priority: 1)
        t["seated_row"] = m(.horizontalPull, priority: 2)
        t["db_row"] = m(.horizontalPull, priority: 3)
        t["db_bent_row"] = m(.horizontalPull, stress: [.lowerBack], priority: 4)
        t["lat_pulldown"] = m(.verticalPull, priority: 2)

        // Shoulders
        t["plank_tap"] = m(.verticalPush, compound: false, stress: [.wrists], ladder: .verticalPush, rung: 0)
        t["pike_pushup"] = m(.verticalPush, stress: [.wrists, .shoulders], ladder: .verticalPush, rung: 1)
        t["elevated_pike"] = m(.verticalPush, stress: [.wrists, .shoulders], ladder: .verticalPush, rung: 2)
        t["overhead_press"] = m(.verticalPush, stress: [.shoulders, .lowerBack], priority: 1)
        t["db_shoulder_press"] = m(.verticalPush, stress: [.shoulders], priority: 2)
        t["arnold_press"] = m(.verticalPush, stress: [.shoulders], priority: 3)
        t["lateral_raise"] = m(.shoulderIsolation, compound: false, priority: 1)
        t["face_pull"] = m(.rearDelt, compound: false)

        // Arms
        t["chair_dip"] = m(.triceps, stress: [.shoulders, .wrists], ladder: .triceps, rung: 0)
        t["close_pushup"] = m(.triceps, stress: [.wrists], ladder: .triceps, rung: 1)
        t["diamond_pushup"] = m(.triceps, stress: [.wrists], ladder: .triceps, rung: 2)
        t["tricep_pushdown"] = m(.triceps, compound: false, priority: 1)
        t["db_tricep_ext"] = m(.triceps, compound: false, priority: 2)
        t["barbell_curl"] = m(.biceps, compound: false, priority: 1)
        t["db_curl"] = m(.biceps, compound: false, priority: 2)
        t["hammer_curl"] = m(.biceps, compound: false, priority: 3)

        // Core
        t["dead_bug"] = m(.coreStability, compound: false, ladder: .coreStability, rung: 0)
        t["plank"] = m(.coreStability, compound: false, ladder: .coreStability, rung: 1)
        t["side_plank"] = m(.coreStability, compound: false, ladder: .coreStability, rung: 2)
        t["hollow_hold"] = m(.coreStability, compound: false, stress: [.lowerBack], ladder: .coreStability, rung: 3)
        t["crunch"] = m(.coreFlexion, compound: false, ladder: .coreFlexion, rung: 0)
        t["bicycle_crunch"] = m(.coreFlexion, compound: false, ladder: .coreFlexion, rung: 0)
        t["leg_raise"] = m(.coreFlexion, compound: false, stress: [.lowerBack], ladder: .coreFlexion, rung: 1)
        t["v_up"] = m(.coreFlexion, compound: false, stress: [.lowerBack], ladder: .coreFlexion, rung: 2)
        t["russian_twist"] = m(.coreRotation, compound: false, stress: [.lowerBack])

        // Cardio
        t["jumping_jacks"] = m(.cardio, compound: false, stress: [.knees], impact: true)
        t["high_knees"] = m(.cardio, compound: false, stress: [.knees], impact: true)
        t["shadow_boxing"] = m(.cardio, compound: false, priority: 1)
        t["burpee"] = m(.cardio, stress: [.knees, .wrists, .shoulders], impact: true)
        t["mountain_climber"] = m(.cardio, compound: false, stress: [.wrists], priority: 2)
        t["skater_hops"] = m(.cardio, compound: false, stress: [.knees], impact: true)

        // Full body
        t["inchworm"] = m(.fullBody, stress: [.wrists])
        t["bear_crawl"] = m(.fullBody, stress: [.wrists, .knees])
        t["db_thruster"] = m(.fullBody, stress: [.knees, .shoulders])
        t["man_maker"] = m(.fullBody, stress: [.wrists, .shoulders, .lowerBack, .knees], impact: true)

        // Mobility
        t["cat_cow"] = m(.mobility, compound: false, stress: [.wrists])
        t["childs_pose"] = m(.mobility, compound: false)
        t["hip_flexor_stretch"] = m(.mobility, compound: false)
        t["hamstring_stretch"] = m(.mobility, compound: false)
        t["thoracic_rotation"] = m(.mobility, compound: false, stress: [.wrists])
        t["worlds_greatest"] = m(.mobility, compound: false)
        t["cobra_stretch"] = m(.mobility, compound: false, stress: [.wrists, .lowerBack])
        t["shoulder_circles"] = m(.mobility, compound: false)
        return t
    }()

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
