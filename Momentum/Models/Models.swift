import Foundation

// MARK: - Profile enums

enum FitnessLevel: String, Codable, CaseIterable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var rank: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }

    static func from(rank: Int) -> FitnessLevel {
        allCases[max(0, min(allCases.count - 1, rank))]
    }

    var summary: String {
        switch self {
        case .beginner: return "New to training or coming back after a long break."
        case .intermediate: return "Training regularly and comfortable with the basics."
        case .advanced: return "Years of consistent training. Ready for volume and load."
        }
    }

    /// Base number of sets for a working exercise.
    var baseSets: Int { rank + 2 }

    /// Scales the starting-weight estimate for loaded exercises.
    var weightFactor: Double {
        switch self {
        case .beginner: return 0.6
        case .intermediate: return 1.0
        case .advanced: return 1.4
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable {
    case buildMuscle, loseFat, stayFit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildMuscle: return "Build muscle"
        case .loseFat: return "Lose fat"
        case .stayFit: return "Stay fit"
        }
    }

    var summary: String {
        switch self {
        case .buildMuscle: return "Heavier loads, fewer reps, longer rests."
        case .loseFat: return "Higher reps, short rests, more cardio flow."
        case .stayFit: return "A balanced mix to feel strong and energetic."
        }
    }

    var symbol: String {
        switch self {
        case .buildMuscle: return "dumbbell.fill"
        case .loseFat: return "flame.fill"
        case .stayFit: return "heart.fill"
        }
    }

    /// Target reps for weighted exercises, by level.
    func loadedReps(for level: FitnessLevel) -> Int {
        switch self {
        case .buildMuscle: return [12, 10, 8][level.rank]
        case .loseFat: return [15, 15, 12][level.rank]
        case .stayFit: return [12, 12, 10][level.rank]
        }
    }

    /// Extra reps added to bodyweight movements.
    var bodyweightBonus: Int {
        switch self {
        case .buildMuscle: return 0
        case .loseFat: return 3
        case .stayFit: return 1
        }
    }

    var restSeconds: Int {
        switch self {
        case .buildMuscle: return 75
        case .loseFat: return 40
        case .stayFit: return 55
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case bodyweight, dumbbells, fullGym

    var id: String { rawValue }

    var rank: Int {
        switch self {
        case .bodyweight: return 0
        case .dumbbells: return 1
        case .fullGym: return 2
        }
    }

    var title: String {
        switch self {
        case .bodyweight: return "No equipment"
        case .dumbbells: return "Dumbbells"
        case .fullGym: return "Full gym"
        }
    }

    var summary: String {
        switch self {
        case .bodyweight: return "Just you, a wall and a chair."
        case .dumbbells: return "A pair of dumbbells at home."
        case .fullGym: return "Barbells, machines and cables."
        }
    }

    var symbol: String {
        switch self {
        case .bodyweight: return "figure.walk"
        case .dumbbells: return "dumbbell"
        case .fullGym: return "figure.strengthtraining.traditional"
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case metric, imperial

    var id: String { rawValue }
    var title: String { self == .metric ? "Metric (kg, cm)" : "Imperial (lb, in)" }
    var weightLabel: String { self == .metric ? "kg" : "lb" }
    var heightLabel: String { self == .metric ? "cm" : "in" }

    private static let poundsPerKg = 2.2046226218
    private static let cmPerInch = 2.54

    func displayWeight(_ kg: Double) -> Double {
        self == .metric ? kg : kg * Self.poundsPerKg
    }

    func kg(fromDisplay value: Double) -> Double {
        self == .metric ? value : value / Self.poundsPerKg
    }

    func displayHeight(_ cm: Double) -> Double {
        self == .metric ? cm : cm / Self.cmPerInch
    }

    func cm(fromDisplay value: Double) -> Double {
        self == .metric ? value : value * Self.cmPerInch
    }

    /// Step used by weight steppers, in display units.
    var weightStep: Double { self == .metric ? 0.5 : 1 }

    func formatWeight(_ kg: Double) -> String {
        let value = (displayWeight(kg) * 2).rounded() / 2
        let text = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return "\(text) \(weightLabel)"
    }
}

struct UserProfile: Codable, Equatable {
    var name: String = ""
    var level: FitnessLevel = .beginner
    var goal: Goal = .stayFit
    var equipment: Equipment = .bodyweight
    var daysPerWeek: Int = 3
    var sessionMinutes: Int = 30
    var weightKg: Double = 70
    var heightCm: Double = 170
    var age: Int = 30
    var units: UnitSystem = .metric
    /// Adaptive difficulty offset, -3 (much easier) ... +3 (much harder).
    var intensity: Int = 0
    var startDate: Date = Date()
    var onboarded: Bool = false
    /// Whether the user connected Apple Health (write workouts and weight, read steps).
    var healthSync: Bool = false

    init() {}

    /// Tolerant decoding so files saved by older versions keep loading when fields are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserProfile()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        level = try c.decodeIfPresent(FitnessLevel.self, forKey: .level) ?? d.level
        goal = try c.decodeIfPresent(Goal.self, forKey: .goal) ?? d.goal
        equipment = try c.decodeIfPresent(Equipment.self, forKey: .equipment) ?? d.equipment
        daysPerWeek = try c.decodeIfPresent(Int.self, forKey: .daysPerWeek) ?? d.daysPerWeek
        sessionMinutes = try c.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? d.sessionMinutes
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg) ?? d.weightKg
        heightCm = try c.decodeIfPresent(Double.self, forKey: .heightCm) ?? d.heightCm
        age = try c.decodeIfPresent(Int.self, forKey: .age) ?? d.age
        units = try c.decodeIfPresent(UnitSystem.self, forKey: .units) ?? d.units
        intensity = try c.decodeIfPresent(Int.self, forKey: .intensity) ?? d.intensity
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate) ?? d.startDate
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        healthSync = try c.decodeIfPresent(Bool.self, forKey: .healthSync) ?? d.healthSync
    }
}

// MARK: - Exercises

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, legs, shoulders, arms, core, cardio, fullBody, mobility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullBody: return "Full body"
        default: return rawValue.capitalized
        }
    }

    var symbol: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .legs: return "figure.step.training"
        case .shoulders: return "figure.arms.open"
        case .arms: return "dumbbell.fill"
        case .core: return "figure.core.training"
        case .cardio: return "figure.highintensity.intervaltraining"
        case .fullBody: return "figure.cross.training"
        case .mobility: return "figure.flexibility"
        }
    }
}

enum ExerciseKind: String, Codable, Hashable {
    case reps, timed
}

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let muscle: MuscleGroup
    let equipment: Equipment
    let level: FitnessLevel
    let kind: ExerciseKind
    /// Metabolic equivalent used for calorie estimates.
    let met: Double
    /// Typical working weight as a fraction of body weight for an intermediate
    /// lifter (per hand for dumbbells). `nil` for bodyweight movements.
    let loadRatio: Double?
    let symbol: String
    let steps: [String]

    var isLoaded: Bool { loadRatio != nil }

    /// A how-to video for this exercise. Uses a curated link from
    /// `ExerciseLibrary.curatedVideos` when there is one, otherwise a YouTube search for proper form.
    var videoURL: URL {
        if let curated = ExerciseLibrary.curatedVideos[id], let url = URL(string: curated) {
            return url
        }
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: "\(name) proper form tutorial")]
        return components.url ?? URL(string: "https://www.youtube.com")!
    }
}

// MARK: - Plans

struct PlannedExercise: Identifiable, Hashable {
    let exerciseID: String
    var sets: Int
    /// Reps for `.reps` exercises, seconds for `.timed` ones.
    var target: Int
    var restSeconds: Int
    /// Suggested working weight in kilograms (per hand for dumbbells).
    var weightKg: Double?

    /// Exercises are unique within a workout, so the exercise id is a stable identity.
    var id: String { exerciseID }

    var exercise: Exercise { ExerciseLibrary.exercise(exerciseID) }

    /// Seconds spent working on one set.
    var workSeconds: Int {
        exercise.kind == .timed ? target : Int((Double(target) * 3.5).rounded())
    }

    /// Total seconds including rest and setup.
    var totalSeconds: Int { sets * (workSeconds + restSeconds) + 15 }

    func calories(weightKg body: Double) -> Double {
        let active = Double(sets * workSeconds)
        let resting = Double(sets * restSeconds + 15)
        return (exercise.met * body * active + 2.0 * body * resting) / 3600.0
    }

    var targetLabel: String {
        exercise.kind == .timed ? "\(sets) × \(target)s" : "\(sets) × \(target)"
    }
}

struct Workout: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    /// Dominant muscle group. Drives the card theme.
    var theme: MuscleGroup
    var exercises: [PlannedExercise]

    var totalSeconds: Int { exercises.reduce(0) { $0 + $1.totalSeconds } }
    var minutes: Int { max(1, Int((Double(totalSeconds) / 60).rounded())) }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }

    func calories(weightKg: Double) -> Int {
        Int(exercises.reduce(0.0) { $0 + $1.calories(weightKg: weightKg) }.rounded())
    }
}

// MARK: - History

enum WorkoutFeedback: String, Codable, CaseIterable, Identifiable {
    case tooEasy, justRight, tooHard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tooEasy: return "Too easy"
        case .justRight: return "Just right"
        case .tooHard: return "Too hard"
        }
    }

    var symbol: String {
        switch self {
        case .tooEasy: return "hare.fill"
        case .justRight: return "hand.thumbsup.fill"
        case .tooHard: return "tortoise.fill"
        }
    }
}

struct SetLog: Codable, Hashable {
    var reps: Int
    var weightKg: Double
    var seconds: Int
}

struct ExerciseLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var exerciseID: String
    var targetSets: Int
    var target: Int
    var sets: [SetLog]
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var title: String
    var durationSeconds: Int
    var calories: Int
    var plannedSets: Int
    var completedSets: Int
    var logs: [ExerciseLog]
    var feedback: WorkoutFeedback?

    var completion: Double {
        plannedSets == 0 ? 0 : Double(completedSets) / Double(plannedSets)
    }
}

struct WeightEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kg: Double
}
