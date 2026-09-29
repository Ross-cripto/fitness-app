import Foundation

/// Plain-language descriptions of past workouts (History screen). Pure functions so they can be tested.
enum SessionSummary {
    /// "10 × 20 kg", "12 reps", "45 sec".
    static func line(for set: SetLog, exercise: Exercise, units: UnitSystem) -> String {
        if exercise.kind == .timed { return L("{0} sec", set.seconds) }
        if exercise.isLoaded && set.weightKg > 0 {
            return L("{0} × {1}", set.reps, units.formatWeight(set.weightKg))
        }
        return Lp(set.reps, one: "{0} rep", other: "{0} reps")
    }

    /// All the sets of one exercise in a session, e.g. "10 × 20 kg · 9 × 20 kg · 8 × 20 kg".
    static func summary(of log: ExerciseLog, units: UnitSystem) -> String {
        guard let exercise = ExerciseLibrary.byID[log.exerciseID] else { return "" }
        return log.sets.map { line(for: $0, exercise: exercise, units: units) }.joined(separator: " · ")
    }

    struct Month: Identifiable {
        /// First day of the month.
        let start: Date
        /// Newest first.
        let sessions: [WorkoutSession]
        var id: Date { start }
    }

    /// Sessions grouped by calendar month, newest month first.
    static func months(_ sessions: [WorkoutSession], calendar: Calendar = Loc.calendar) -> [Month] {
        let grouped = Dictionary(grouping: sessions) { session -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: session.date)) ?? session.date
        }
        return grouped
            .map { Month(start: $0.key, sessions: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.start > $1.start }
    }
}
