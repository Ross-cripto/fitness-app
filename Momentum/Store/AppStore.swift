import Foundation
import SwiftUI

struct VolumeRow: Identifiable {
    let muscle: MuscleGroup
    let done: Int
    let target: VolumeTarget
    var id: MuscleGroup { muscle }
}

struct DayMinutes: Identifiable {
    let date: Date
    let minutes: Int
    var id: Date { date }
}

struct RecordEntry: Identifiable {
    let exercise: Exercise
    let kg: Double
    var id: String { exercise.id }
}

struct Totals: Equatable {
    var calories = 0
    var seconds = 0
    var sets = 0
    var sessions = 0

    var minutes: Int { seconds / 60 }
}

/// Single source of truth. Everything lives in one JSON file in the app's
/// Documents folder. No account, no network, no analytics.
@MainActor
final class AppStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet {
            applyLanguage()
            save()
        }
    }
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var weights: [WeightEntry] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? AppStore.defaultURL()
        self.fileURL = url
        if let data = try? Data(contentsOf: url) {
            if let snapshot = try? AppStore.decoder.decode(PersonalData.self, from: data) {
                profile = snapshot.profile
                sessions = snapshot.sessions
                weights = snapshot.weights
            } else {
                // Never overwrite data we couldn't read: keep a copy first.
                let backup = url.deletingLastPathComponent().appendingPathComponent("momentum-data.unreadable.json")
                try? FileManager.default.removeItem(at: backup)
                try? FileManager.default.copyItem(at: url, to: backup)
                profile = UserProfile()
            }
        } else {
            profile = UserProfile()
        }
        applyLanguage()
    }

    /// The language in use: the person's choice, or the phone's.
    var language: AppLanguage { profile.language ?? .detect() }

    /// Points the runtime translator at the chosen language. Views re-render because `profile` is published.
    private func applyLanguage() {
        Loc.language = language
    }

    // MARK: Persistence

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("momentum-data.json")
    }

    private func save() {
        let snapshot = PersonalData(profile: profile, sessions: sessions, weights: weights)
        guard let data = try? AppStore.encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    // MARK: Backup

    /// The whole history as a JSON backup the person can keep anywhere.
    func exportBackup() throws -> Data {
        try Backup.export(PersonalData(profile: profile, sessions: sessions, weights: weights))
    }

    /// Workout history as CSV (one row per set) for spreadsheets.
    func exportCSV() -> String {
        Backup.csv(sessions: sessions)
    }

    /// Replaces everything without a backup file (demo data, UI tests).
    func seed(_ data: PersonalData) {
        sessions = data.sessions
        weights = data.weights
        profile = data.profile
    }

    /// Replaces everything with the contents of a backup. The current data is kept in a side file first, so a
    /// wrong file can be undone by hand. Throws (and changes nothing) when the file is not a valid backup.
    func restore(from data: Data) throws {
        let restored = try Backup.read(data)
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("momentum-data.before-restore.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: fileURL, to: backup)
        sessions = restored.sessions
        weights = restored.weights
        profile = restored.profile   // saves everything
    }

    // MARK: Profile & body weight

    /// Finishes onboarding: places the person (level and starting rung on every ladder) and starts the first block.
    func completeOnboarding(_ newProfile: UserProfile) {
        var updated = newProfile
        let placement = Assessment.place(updated)
        updated.level = placement.level
        updated.rungs = placement.rungs
        updated.onboarded = true
        updated.startDate = Date()
        updated.blockStart = TrainingCalendar.weekStart(of: Date())
        updated.blockOffset = 0
        updated.intensity = 0
        updated.deloadWeekStart = nil
        updated.levelChangedAt = nil
        updated.rungChangedAt = [:]
        if updated.trainingWeekdays.isEmpty { updated.trainingWeekdays = PlanGenerator.defaultWeekdays(forDays: 3) }
        weights = [WeightEntry(date: Date(), kg: updated.weightKg)]
        profile = updated // didSet saves
    }

    func addWeight(kg: Double, on date: Date = Date()) {
        weights.append(WeightEntry(date: date, kg: kg))
        weights.sort { $0.date < $1.date }
        profile.weightKg = weights.last?.kg ?? kg
    }

    func resetAll() {
        let language = profile.language
        sessions = []
        weights = []
        profile = UserProfile()
        profile.language = language
    }

    /// Clears the adaptive state (difficulty offset, deloads, rung history) and re-places the person from their
    /// original onboarding answers.
    func resetAdaptation() {
        var updated = profile
        let placement = Assessment.place(updated)
        updated.level = placement.level
        updated.rungs = placement.rungs
        updated.intensity = 0
        updated.deloadWeekStart = nil
        updated.levelChangedAt = nil
        updated.rungChangedAt = [:]
        updated.blockStart = TrainingCalendar.weekStart(of: Date())
        updated.blockOffset = 0
        profile = updated
    }

    // MARK: Plans

    /// How the person says they feel today. Only affects today's workout and resets each day.
    @Published private(set) var readiness: Readiness = .normal
    private var readinessDay = Calendar.current.startOfDay(for: Date())

    var todaysReadiness: Readiness {
        Calendar.current.isDateInToday(readinessDay) ? readiness : .normal
    }

    func setReadiness(_ value: Readiness) {
        readinessDay = Calendar.current.startOfDay(for: Date())
        readiness = value
    }

    func workout(on date: Date) -> Workout? {
        let ready = Calendar.current.isDateInToday(date) ? todaysReadiness : .normal
        return PlanGenerator.workout(on: date, profile: profile, history: sessions, readiness: ready)
    }

    func nextWorkout() -> (date: Date, workout: Workout)? {
        PlanGenerator.nextWorkout(after: Date(), profile: profile, history: sessions)
    }

    func quick(_ kind: QuickKind) -> Workout {
        PlanGenerator.quick(kind, profile: profile, history: sessions)
    }

    // MARK: Sessions

    /// Saves a finished session and adapts the plan (progression state, level, deloads).
    /// Returns plain-language notes about what changed.
    @discardableResult
    func record(_ session: WorkoutSession) -> [String] {
        let previous = sessions.map { $0.date }.max()
        sessions.append(session)
        let outcome = AdaptiveEngine.apply(
            session: session, to: profile, history: sessions, previousSessionDate: previous
        )
        profile = outcome.profile   // didSet saves
        return outcome.messages
    }

    // MARK: Swaps

    /// Remembers how a swap should be handled in future plans.
    func rememberSwap(original: Exercise, replacement: Exercise, scope: SwapScope, protecting areas: [BodyArea] = []) {
        var updated = profile
        updated.applySwap(original: original, replacement: replacement, scope: scope, protecting: areas)
        profile = updated
    }

    /// Estimated one-rep max per lift from the best set ever logged.
    func bestEstimatedOneRepMax(for exerciseID: String) -> Double? {
        var best: Double?
        for session in sessions {
            for log in session.logs where log.exerciseID == exerciseID {
                for set in log.sets {
                    if let value = Progression.estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps) {
                        best = max(best ?? 0, value)
                    }
                }
            }
        }
        return best
    }

    func delete(_ session: WorkoutSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func sessions(on date: Date) -> [WorkoutSession] {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func totals(on date: Date) -> Totals {
        Self.totals(of: sessions(on: date))
    }

    private static func totals(of list: [WorkoutSession]) -> Totals {
        var totals = Totals()
        for session in list {
            totals.calories += session.calories
            totals.seconds += session.durationSeconds
            totals.sets += session.completedSets
            totals.sessions += 1
        }
        return totals
    }

    // MARK: Weekly progress

    private func weekDays(containing date: Date) -> [Date] {
        let calendar = PlanGenerator.calendar
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [date] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func weekTotals(containing date: Date) -> Totals {
        let days = weekDays(containing: date)
        let calendar = Calendar.current
        return Self.totals(of: sessions.filter { session in
            days.contains { calendar.isDate($0, inSameDayAs: session.date) }
        })
    }

    /// What the plan asks for across the week: (calories, minutes).
    func weeklyGoal(containing date: Date) -> (calories: Int, minutes: Int) {
        var calories = 0
        var minutes = 0
        for day in weekDays(containing: date) {
            if let planned = PlanGenerator.workout(on: day, profile: profile, history: []) {
                calories += planned.calories(weightKg: profile.weightKg)
                minutes += planned.minutes
            }
        }
        return (calories, minutes)
    }

    /// Completed sets per muscle this week vs the planned target range.
    func volumeThisWeek(containing date: Date = Date()) -> [VolumeRow] {
        let done = VolumePlanner.completedSets(in: sessions, weekContaining: date)
        let targets = VolumePlanner.weeklyTargets(for: profile)
        return VolumePlanner.muscles.compactMap { muscle in
            guard let target = targets[muscle] else { return nil }
            return VolumeRow(muscle: muscle, done: done[muscle] ?? 0, target: target)
        }
    }

    /// Active minutes per day for the `days` days ending on `end`.
    func dailyMinutes(endingAt end: Date, days: Int) -> [DayMinutes] {
        let calendar = Calendar.current
        return (0..<days).reversed().compactMap { offset -> DayMinutes? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return DayMinutes(date: day, minutes: totals(on: day).minutes)
        }
    }

    /// Consecutive training days completed without skipping a scheduled one.
    var streak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let origin = calendar.startOfDay(for: profile.startDate)
        var count = 0
        var day = today
        for _ in 0..<400 {
            if !sessions(on: day).isEmpty {
                count += 1
            } else if day != today && PlanGenerator.isTrainingDay(day, profile: profile) {
                break
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day), previous >= origin else { break }
            day = previous
        }
        return count
    }

    // MARK: Records

    func personalRecords(limit: Int = 5) -> [RecordEntry] {
        var best: [String: Double] = [:]
        for session in sessions {
            for log in session.logs {
                for set in log.sets where set.weightKg > 0 {
                    best[log.exerciseID] = max(best[log.exerciseID] ?? 0, set.weightKg)
                }
            }
        }
        let records = best.map { RecordEntry(exercise: ExerciseLibrary.exercise($0.key), kg: $0.value) }
        return Array(records.sorted { $0.kg > $1.kg }.prefix(limit))
    }

    /// Best set (by weight, then reps) ever logged for an exercise.
    func bestSet(for exerciseID: String) -> SetLog? {
        sessions
            .flatMap { $0.logs }
            .filter { $0.exerciseID == exerciseID }
            .flatMap { $0.sets }
            .max { ($0.weightKg, $0.reps, $0.seconds) < ($1.weightKg, $1.reps, $1.seconds) }
    }
}
