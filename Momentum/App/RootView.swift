import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.profile.onboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.locale, store.language.locale)
        // Text follows the person's size setting up to a point where fixed-size cards would break.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        // Rebuild the tree when the language changes so every string is looked up again.
        .id(store.language)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 1

    /// Changes whenever the reminders may need to be planned again.
    private var reminderKey: String {
        "\(scenePhase == .active)|\(store.profile.reminderMinutes ?? -1)|\(store.profile.trainingWeekdays)|\(store.sessions.count)|\(store.language.rawValue)|\(store.profile.name)"
    }

    var body: some View {
        TabView(selection: $tab) {
            ProgressTabView()
                .tabItem { Image(systemName: "chart.pie.fill").accessibilityLabel(L("Progress")) }
                .tag(0)
            WorkoutsView()
                .tabItem { Image(systemName: "flame.fill").accessibilityLabel(L("Workouts")) }
                .tag(1)
            ExploreView()
                .tabItem { Image(systemName: "magnifyingglass").accessibilityLabel(L("Explore")) }
                .tag(2)
        }
        .tint(Theme.pink)
        .task(id: reminderKey) {
            await ReminderScheduler.reschedule(profile: store.profile, history: store.sessions)
        }
    }
}
