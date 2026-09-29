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
        // Rebuild the tree when the language changes so every string is looked up again.
        .id(store.language)
    }
}

struct MainTabView: View {
    @State private var tab = 1

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
    }
}
