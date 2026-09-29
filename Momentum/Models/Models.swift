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
    case buildMuscle, getStronger, loseFat, stayFit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buildMuscle: return "Build muscle"
        case .getStronger: return "Get stronger"
        case .loseFat: return "Lose fat"
        case .stayFit: return "General fitness"
        }
    }

    var summary: String {
        switch self {
        case .buildMuscle: return "More muscle size. Moderate reps, plenty of weekly volume."
        case .getStronger: return "Lift heavier over time. Fewer reps, longer rests."
        case .loseFat: return "Higher reps, shorter rests and a cardio finisher."
        case .stayFit: return "A balanced routine to feel strong and energetic."
        }
    }

    var symbol: String {
        switch self {
        case .buildMuscle: return "dumbbell.fill"
        case .getStronger: return "bolt.fill"
        case .loseFat: return "flame.fill"
        case .stayFit: return "heart.fill"
        }
    }

    /// Multiplier on the weekly volume targets.
    var volumeFactor: Double {
        switch self {
        case .buildMuscle: return 1.0
        case .getStronger: return 0.85
        case .loseFat: return 0.85
        case .stayFit: return 0.7
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
        case .bodyweight: return "Just you, a wall and a sturdy chair."
        case .dumbbells: return "A pair (or set) of dumbbells at home."
        case .fullGym: return "Barbells, machines, cables and a pull-up bar."
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

enum Sex: String, Codable, CaseIterable, Identifiable {
    case female, male, unspecified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .unspecified: return "Prefer not to say"
        }
    }
}

/// Body areas the person wants to protect. Exercises that stress them are never chosen.
enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case knees, lowerBack, shoulders, wrists

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knees: return "Knees"
        case .lowerBack: return "Lower back"
        case .shoulders: return "Shoulders"
        case .wrists: return "Wrists"
        }
    }

    var symbol: String {
        switch self {
        case .knees: return "figure.walk"
        case .lowerBack: return "figure.stand"
        case .shoulders: return "figure.arms.open"
        case .wrists: return "hand.raised.fill"
        }
    }
}

enum TrainingHistory: Int, Codable, CaseIterable, Identifiable {
    case never = 0, under6Months, sixTo24Months, over2Years

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .never: return "Never, or just starting"
        case .under6Months: return "Less than 6 months"
        case .sixTo24Months: return "6 months to 2 years"
        case .over2Years: return "More than 2 years"
        }
    }
}

/// Workouts per week over the last three months.
enum RecentFrequency: Int, Codable, CaseIterable, Identifiable {
    case none = 0, oneToTwo, threeToFour, fivePlus

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "None lately"
        case .oneToTwo: return "1-2 times a week"
        case .threeToFour: return "3-4 times a week"
        case .fivePlus: return "5+ times a week"
        }
    }
}

/// Optional self-test. `nil` means "skipped".
struct FitnessCheck: Codable, Equatable {
    var pushups: Int?
    var squats: Int?
    var plankSeconds: Int?
    var pullups: Int?

    init(pushups: Int? = nil, squats: Int? = nil, plankSeconds: Int? = nil, pullups: Int? = nil) {
        self.pushups = pushups
        self.squats = squats
        self.plankSeconds = plankSeconds
        self.pullups = pullups
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
    var sessionMinutes: Int = 30
    var weightKg: Double = 70
    var heightCm: Double = 170
    var age: Int = 30
    var sex: Sex = .unspecified
    var units: UnitSystem = .metric
    var startDate: Date = Date()
    var onboarded: Bool = false
    /// Whether the user connected Apple Health (write workouts and weight, read steps).
    var healthSync: Bool = false

    // Placement inputs (kept so the plan can be explained and re-derived).
    var history: TrainingHistory = .never
    var frequency: RecentFrequency = .none
    var check: FitnessCheck = FitnessCheck()

    /// Calendar weekdays (1 = Sunday ... 7 = Saturday) the person can train. Empty = use a sensible default.
    var trainingWeekdays: [Int] = []
    var limitations: [BodyArea] = []
    var lowImpactOnly: Bool = false
    /// Heaviest single dumbbell in kilograms. 0 means "no limit".
    var maxDumbbellKg: Double = 0
    var excludedExercises: [String] = []
    /// original exercise id -> preferred replacement id (remembered from swaps).
    var swapPreferences: [String: String] = [:]

    // Adaptive state.
    /// Difficulty offset, -3 (much easier) ... +3 (much harder).
    var intensity: Int = 0
    /// Current rung per progression ladder (see `Ladder`), keyed by `Ladder.rawValue`.
    var rungs: [String: Int] = [:]
    /// Monday of the first week of the current training block.
    var blockStart: Date = Date()
    /// Monday of a week that was turned into a deload because of accumulated fatigue.
    var deloadWeekStart: Date?
    /// When the level last changed (level moves at most once every four weeks).
    var levelChangedAt: Date?
    /// When each ladder last changed rung, keyed by `Ladder.rawValue`.
    var rungChangedAt: [String: Date] = [:]

    init() {}

    /// Tolerant decoding so files saved by older versions keep loading when fields are added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UserProfile()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        name = value(.name, d.name)
        level = value(.level, d.level)
        goal = value(.goal, d.goal)
        equipment = value(.equipment, d.equipment)
        sessionMinutes = value(.sessionMinutes, d.sessionMinutes)
        weightKg = value(.weightKg, d.weightKg)
        heightCm = value(.heightCm, d.heightCm)
        age = value(.age, d.age)
        sex = value(.sex, d.sex)
        units = value(.units, d.units)
        startDate = value(.startDate, d.startDate)
        onboarded = value(.onboarded, d.onboarded)
        healthSync = value(.healthSync, d.healthSync)
        history = value(.history, d.history)
        frequency = value(.frequency, d.frequency)
        check = value(.check, d.check)
        trainingWeekdays = value(.trainingWeekdays, d.trainingWeekdays)
        limitations = value(.limitations, d.limitations)
        lowImpactOnly = value(.lowImpactOnly, d.lowImpactOnly)
        maxDumbbellKg = value(.maxDumbbellKg, d.maxDumbbellKg)
        excludedExercises = value(.excludedExercises, d.excludedExercises)
        swapPreferences = value(.swapPreferences, d.swapPreferences)
        intensity = value(.intensity, d.intensity)
        rungs = value(.rungs, d.rungs)
        blockStart = value(.blockStart, d.blockStart)
        deloadWeekStart = try? c.decodeIfPresent(Date.self, forKey: .deloadWeekStart)
        levelChangedAt = try? c.decodeIfPresent(Date.self, forKey: .levelChangedAt)
        rungChangedAt = value(.rungChangedAt, d.rungChangedAt)
    }

    /// Days per week the person trains (derived from the chosen weekdays).
    var daysPerWeek: Int { trainingWeekdays.isEmpty ? 3 : trainingWeekdays.count }
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

struct RampSet: Hashable {
    var weightKg: Double
    var reps: Int
}

/// The prescription for one exercise in one session.
struct PlannedExercise: Identifiable, Hashable {
    let exerciseID: String
    var sets: Int
    /// Target reps for `.reps` exercises, seconds for `.timed` ones.
    var target: Int
    /// Rep (or second) range this exercise is progressed within.
    var repMin: Int
    var repMax: Int
    var restSeconds: Int
    /// Suggested working weight in kilograms (per hand for dumbbells).
    var weightKg: Double?
    /// Reps in reserve to aim for on the last sets.
    var repsInReserve: Int?
    /// One-line explanation of why this is prescribed (progression, deload, comeback...).
    var reason: String?
    /// Lighter warm-up sets before the working sets.
    var rampSets: [RampSet]

    init(
        exerciseID: String,
        sets: Int,
        target: Int,
        repMin: Int? = nil,
        repMax: Int? = nil,
        restSeconds: Int,
        weightKg: Double? = nil,
        repsInReserve: Int? = nil,
        reason: String? = nil,
        rampSets: [RampSet] = []
    ) {
        self.exerciseID = exerciseID
        self.sets = sets
        self.target = target
        self.repMin = repMin ?? target
        self.repMax = repMax ?? target
        self.restSeconds = restSeconds
        self.weightKg = weightKg
        self.repsInReserve = repsInReserve
        self.reason = reason
        self.rampSets = rampSets
    }

    /// Exercises are unique within a workout, so the exercise id is a stable identity.
    var id: String { exerciseID }

    var exercise: Exercise { ExerciseLibrary.exercise(exerciseID) }

    /// Seconds spent working on one set.
    var workSeconds: Int {
        exercise.kind == .timed ? target : Int((Double(target) * 3.5).rounded())
    }

    /// Total seconds including rest, warm-up sets and setup.
    var totalSeconds: Int {
        let ramp = rampSets.reduce(0) { $0 + Int((Double($1.reps) * 3.5).rounded()) + 45 }
        return sets * (workSeconds + restSeconds) + 15 + ramp
    }

    func calories(weightKg body: Double) -> Double {
        let active = Double(sets * workSeconds)
        let resting = Double(sets * restSeconds + 15)
        return (exercise.met * body * active + 2.0 * body * resting) / 3600.0
    }

    var targetLabel: String {
        if exercise.kind == .timed { return "\(sets) × \(target)s" }
        return repMax > repMin ? "\(sets) × \(repMin)-\(repMax)" : "\(sets) × \(target)"
    }
}

/// Where the current week sits in the training block.
struct WeekPhase: Hashable {
    /// 0-based position in the block.
    var weekInBlock: Int
    var blockLength: Int
    var isDeload: Bool
    /// Reps in reserve to aim for this week.
    var repsInReserve: Int

    var label: String {
        isDeload ? "Deload week" : "Week \(weekInBlock + 1) of \(blockLength - 1)"
    }
}

struct Workout: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String
    /// Dominant muscle group. Drives the card theme.
    var theme: MuscleGroup
    var warmup: [PlannedExercise]
    var exercises: [PlannedExercise]
    var phase: WeekPhase?
    /// Headline note shown above the exercises (deload, comeback, low readiness...).
    var note: String?
    /// The day this workout is planned for (nil for quick workouts).
    var date: Date?

    init(
        id: String,
        title: String,
        subtitle: String,
        theme: MuscleGroup,
        warmup: [PlannedExercise] = [],
        exercises: [PlannedExercise],
        phase: WeekPhase? = nil,
        note: String? = nil,
        date: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.theme = theme
        self.warmup = warmup
        self.exercises = exercises
        self.phase = phase
        self.note = note
        self.date = date
    }

    var totalSeconds: Int { (warmup + exercises).reduce(0) { $0 + $1.totalSeconds } }
    var minutes: Int { max(1, Int((Double(totalSeconds) / 60).rounded())) }
    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }

    func calories(weightKg: Double) -> Int {
        Int((warmup + exercises).reduce(0.0) { $0 + $1.calories(weightKg: weightKg) }.rounded())
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

/// How one exercise felt.
enum Effort: String, Codable, CaseIterable, Identifiable {
    case easy, good, hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .good: return "Good"
        case .hard: return "Hard"
        }
    }
}

/// How ready the person feels today.
enum Readiness: String, Codable, CaseIterable, Identifiable {
    case low, normal, great

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Rough"
        case .normal: return "Okay"
        case .great: return "Great"
        }
    }

    var symbol: String {
        switch self {
        case .low: return "battery.25"
        case .normal: return "battery.75"
        case .great: return "battery.100"
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
    /// Rep range planned for the session (nil in logs saved by older versions).
    var repMin: Int?
    var repMax: Int?
    var effort: Effort?
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
    var readiness: Readiness?
    var wasDeload: Bool?

    var completion: Double {
        plannedSets == 0 ? 0 : Double(completedSets) / Double(plannedSets)
    }
}

struct WeightEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var kg: Double
}
