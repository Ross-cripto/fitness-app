import Foundation
import SwiftUI

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
    private struct Snapshot: Codable {
        var profile: UserProfile
        var sessions: [WorkoutSession]
        var weights: [WeightEntry]
    }

    @Published var profile: UserProfile { didSet { save() } }
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var weights: [WeightEntry] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let url = fileURL ?? AppStore.defaultURL()
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let snapshot = try? AppStore.decoder.decode(Snapshot.self, from: data) {
            profile = snapshot.profile
            sessions = snapshot.sessions
            weights = snapshot.weights
        } else {
            profile = UserProfile()
        }
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
        let snapshot = Snapshot(profile: profile, sessions: sessions, weights: weights)
        guard let data = try? AppStore.encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    // MARK: Profile & body weight

    func completeOnboarding(_ newProfile: UserProfile) {
        var updated = newProfile
        updated.onboarded = true
        updated.startDate = Date()
        updated.intensity = 0
        weights = [WeightEntry(date: Date(), kg: updated.weightKg)]
        profile = updated // didSet saves
    }

    func addWeight(kg: Double, on date: Date = Date()) {
        weights.append(WeightEntry(date: date, kg: kg))
        weights.sort { $0.date < $1.date }
        profile.weightKg = kg
    }

    func resetAll() {
        sessions = []
        weights = []
        profile = UserProfile()
    }

    func resetAdaptation() {
        profile.intensity = 0
    }

    // MARK: Plans

    func workout(on date: Date) -> Workout? {
        PlanGenerator.workout(on: date, profile: profile, history: sessions)
    }

    func nextWorkout() -> (date: Date, workout: Workout)? {
        PlanGenerator.nextWorkout(after: Date(), profile: profile, history: sessions)
    }

    func quick(_ kind: QuickKind) -> Workout {
        PlanGenerator.quick(kind, profile: profile, history: sessions)
    }

    // MARK: Sessions

    /// Saves a finished session and adapts the plan from the feedback.
    /// Returns a message describing the adaptation, if any.
    @discardableResult
    func record(_ session: WorkoutSession) -> String? {
        sessions.append(session)
        var message: String?
        if let feedback = session.feedback {
            let outcome = AdaptiveEngine.evaluate(
                level: profile.level,
                intensity: profile.intensity,
                feedback: feedback,
                completion: session.completion
            )
            var updated = profile
            updated.level = outcome.level
            updated.intensity = outcome.intensity
            profile = updated
            message = outcome.message
        } else {
            save()
        }
        return message
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
            if let planned = workout(on: day) {
                calories += planned.calories(weightKg: profile.weightKg)
                minutes += planned.minutes
            }
        }
        return (calories, minutes)
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
