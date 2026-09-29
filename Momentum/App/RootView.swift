import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        if store.profile.onboarded {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

struct MainTabView: View {
    @State private var tab = 1

    var body: some View {
        TabView(selection: $tab) {
            ProgressTabView()
                .tabItem { Image(systemName: "chart.pie.fill").accessibilityLabel("Progress") }
                .tag(0)
            WorkoutsView()
                .tabItem { Image(systemName: "flame.fill").accessibilityLabel("Workouts") }
                .tag(1)
            ExploreView()
                .tabItem { Image(systemName: "magnifyingglass").accessibilityLabel("Explore") }
                .tag(2)
        }
        .tint(Theme.pink)
    }
}
