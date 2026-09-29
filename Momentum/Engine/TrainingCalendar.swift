import Foundation

/// Weeks run Monday to Sunday everywhere in the engine.
enum TrainingCalendar {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static func weekStart(of date: Date) -> Date {
        let calendar = self.calendar
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Whole weeks between the weeks containing `start` and `date` (never negative).
    static func weeksBetween(_ start: Date, and date: Date) -> Int {
        let days = calendar.dateComponents([.day], from: weekStart(of: start), to: weekStart(of: date)).day ?? 0
        return max(0, days / 7)
    }

    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        let calendar = self.calendar
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}
