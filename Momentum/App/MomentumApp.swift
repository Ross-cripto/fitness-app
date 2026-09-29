import SwiftUI

@main
struct MomentumApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var health = HealthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(health)
        }
    }
}
