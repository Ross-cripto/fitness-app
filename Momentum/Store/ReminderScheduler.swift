import Foundation
import UserNotifications

/// Puts `Reminders.plan` on the system as local notifications. Nothing leaves the device.
@MainActor
enum ReminderScheduler {
    private static let prefix = "momentum.reminder."

    /// Asks for permission to show notifications. False when the person (or an earlier choice) said no.
    static func requestAccess() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    /// Replaces the pending reminders with the current plan (or none, when reminders are off).
    static func reschedule(profile: UserProfile, history: [WorkoutSession]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })

        guard profile.reminderMinutes != nil else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let calendar = TrainingCalendar.calendar
        for (index, reminder) in Reminders.plan(profile: profile, history: history, now: Date()).enumerated() {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "\(prefix)\(index)", content: content, trigger: trigger))
        }
    }
}
