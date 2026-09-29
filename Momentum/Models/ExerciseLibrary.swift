import Foundation

/// One entry of `data/exercises.json`: everything the app knows about an exercise except its translations and
/// animation. Decoded from `ExerciseCatalog.json` (generated from that file by `tools/exercises/export.py`).
struct ExerciseRecord: Decodable {
    let id: String
    let name: String
    let muscle: MuscleGroup
    let equipment: Equipment
    let level: FitnessLevel
    let kind: ExerciseKind
    let met: Double
    /// Typical working weight as a fraction of body weight (nil for bodyweight movements).
    let load: Double?
    let symbol: String?
    let pattern: Pattern
    let compound: Bool
    let stress: [BodyArea]
    let impact: Bool
    let ladder: Ladder?
    let rung: Int
    let priority: Int
    let video: String?
    let steps: [String]

    var exercise: Exercise {
        Exercise(
            id: id, englishName: name, muscle: muscle, equipment: equipment, level: level, kind: kind, met: met,
            loadRatio: load, symbol: symbol ?? muscle.symbol, englishSteps: steps
        )
    }

    var meta: ExerciseMeta {
        ExerciseMeta(pattern: pattern, isCompound: compound, stress: stress, isImpact: impact, ladder: ladder,
                     rung: rung, priority: priority)
    }
}

/// The built-in exercise catalogue. Everything ships with the app, so the
/// whole product works offline and never talks to a server.
///
/// The source of truth is `data/exercises.json`; edit that and run `python3 tools/exercises/export.py`.
enum ExerciseLibrary {
    static let records: [ExerciseRecord] = {
        guard let data = ExerciseCatalog.json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([ExerciseRecord].self, from: data)
        } catch {
            fatalError("ExerciseCatalog.swift is not valid: \(error). Run tools/exercises/export.py.")
        }
    }()

    static let all: [Exercise] = records.map(\.exercise)

    static func exercise(_ id: String) -> Exercise {
        byID[id] ?? all[0]
    }

    /// Optional hand-picked video per exercise id (the `video` field in the catalogue).
    /// Exercises without one link to a YouTube search for proper form instead.
    static let curatedVideos: [String: String] = {
        var map: [String: String] = [:]
        for record in records { if let video = record.video { map[record.id] = video } }
        return map
    }()

    static let byID: [String: Exercise] = {
        var map: [String: Exercise] = [:]
        for exercise in all { map[exercise.id] = exercise }
        return map
    }()
}
