import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $store.profile.name)
                    Picker("Level", selection: $store.profile.level) {
                        ForEach(FitnessLevel.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Goal", selection: $store.profile.goal) {
                        ForEach(Goal.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Equipment", selection: $store.profile.equipment) {
                        ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section("Schedule") {
                    Stepper(value: $store.profile.daysPerWeek, in: 1...6) {
                        Text("\(store.profile.daysPerWeek) days per week")
                    }
                    Picker("Session length", selection: $store.profile.sessionMinutes) {
                        ForEach([20, 30, 45, 60], id: \.self) { Text("\($0) min").tag($0) }
                    }
                }

                Section("Body") {
                    Picker("Units", selection: $store.profile.units) {
                        ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(value: $store.profile.age, in: 14...90) {
                        Text("Age: \(store.profile.age)")
                    }
                    LabeledContent("Weight", value: store.profile.units.formatWeight(store.profile.weightKg))
                }

                Section {
                    Toggle("Sync with Apple Health", isOn: healthBinding)
                        .tint(Theme.pink)
                        .disabled(!HealthService.isAvailable)
                    if let message = health.lastError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Apple Health")
                } footer: {
                    Text("Saves finished workouts and body weight to Health, and reads your steps and active energy. Data stays on this device and in your Health app. You can change permissions any time in Settings → Health → Data Access & Devices.")
                }

                Section {
                    LabeledContent("Adaptive intensity", value: intensityText)
                    Button("Reset adaptation") { store.resetAdaptation() }
                } header: {
                    Text("Adaptive plan")
                } footer: {
                    Text("Every workout you rate nudges this up or down. At the extremes your level changes automatically. Weights go up when you hit every rep and drop when you fall short.")
                }

                Section {
                    Button("Delete all data", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Momentum is free and works fully offline. All data is stored only on this device.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete all workouts, weights and settings?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    store.resetAll()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var healthBinding: Binding<Bool> {
        Binding(
            get: { store.profile.healthSync },
            set: { enabled in
                if enabled {
                    Task { @MainActor in
                        let granted = await health.requestAccess()
                        store.profile.healthSync = granted
                        if granted { await health.refreshToday() }
                    }
                } else {
                    store.profile.healthSync = false
                    health.clearError()
                }
            }
        )
    }

    private var intensityText: String {
        let value = store.profile.intensity
        if value == 0 { return "Baseline" }
        return value > 0 ? "+\(value) tougher" : "\(value) easier"
    }
}
