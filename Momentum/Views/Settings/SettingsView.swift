import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var confirmRePlace = false

    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $store.profile.name)
                    Picker("Goal", selection: $store.profile.goal) {
                        ForEach(Goal.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Level", selection: $store.profile.level) {
                        ForEach(FitnessLevel.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Equipment", selection: $store.profile.equipment) {
                        ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                    }
                    if store.profile.equipment == .dumbbells {
                        Stepper(value: dumbbellBinding, in: 0...130, step: 1) {
                            Text(store.profile.maxDumbbellKg == 0
                                 ? "Heaviest dumbbell: no limit"
                                 : "Heaviest dumbbell: \(Int(dumbbellBinding.wrappedValue)) \(store.profile.units.weightLabel)")
                        }
                    }
                }

                Section {
                    HStack(spacing: 6) {
                        ForEach(Self.weekdayOrder, id: \.self) { weekday in
                            let on = store.profile.trainingWeekdays.contains(weekday)
                            Button { toggle(weekday) } label: {
                                Text(Calendar.current.veryShortWeekdaySymbols[weekday - 1])
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(on ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? Theme.pink : Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    Picker("Session length", selection: $store.profile.sessionMinutes) {
                        ForEach([20, 30, 45, 60, 90], id: \.self) { Text("\($0) min").tag($0) }
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    Text("\(store.profile.trainingWeekdays.count) days a week. Changing days re-plans upcoming workouts.")
                }

                Section {
                    ForEach(BodyArea.allCases) { area in
                        Toggle(area.title, isOn: binding(for: area))
                    }
                    Toggle("Low impact only (no jumping)", isOn: $store.profile.lowImpactOnly)
                } header: {
                    Text("Protect")
                } footer: {
                    Text("Exercises that load these areas are never picked. Not medical advice: if something hurts, see a professional.")
                }

                Section("Body") {
                    Picker("Sex", selection: $store.profile.sex) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Units", selection: $store.profile.units) {
                        ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(value: $store.profile.age, in: 14...90) {
                        Text("Age: \(store.profile.age)")
                    }
                    LabeledContent("Weight", value: store.profile.units.formatWeight(store.profile.weightKg))
                }

                if !store.profile.excludedExercises.isEmpty || !store.profile.swapPreferences.isEmpty {
                    Section {
                        ForEach(store.profile.excludedExercises, id: \.self) { id in
                            HStack {
                                Text(ExerciseLibrary.exercise(id).name)
                                Spacer()
                                Button("Show again") { showAgain(id) }
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        ForEach(store.profile.swapPreferences.keys.sorted(), id: \.self) { id in
                            if !store.profile.excludedExercises.contains(id), let replacement = store.profile.swapPreferences[id] {
                                HStack {
                                    Text("\(ExerciseLibrary.exercise(id).name) → \(ExerciseLibrary.exercise(replacement).name)")
                                        .font(.system(size: 14))
                                    Spacer()
                                    Button("Undo") { store.profile.swapPreferences[id] = nil }
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    } header: {
                        Text("Your swaps")
                    } footer: {
                        Text("Exercises you hid or replaced from a workout.")
                    }
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
                    LabeledContent("Difficulty offset", value: intensityText)
                    LabeledContent("Training block", value: blockText)
                    Button("Re-place me from my onboarding answers") { confirmRePlace = true }
                } header: {
                    Text("Adaptive plan")
                } footer: {
                    Text("Your level, exercise steps and difficulty change on their own from how you train. Re-placing clears that history and starts again from your answers.")
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
            .confirmationDialog("Reset your adaptive plan?", isPresented: $confirmRePlace, titleVisibility: .visible) {
                Button("Re-place me") { store.resetAdaptation() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: Helpers

    private func toggle(_ weekday: Int) {
        var days = store.profile.trainingWeekdays
        if let index = days.firstIndex(of: weekday) {
            if days.count > 1 { days.remove(at: index) }
        } else if days.count < 6 {
            days.append(weekday)
        }
        store.profile.trainingWeekdays = days
    }

    private func binding(for area: BodyArea) -> Binding<Bool> {
        Binding(
            get: { store.profile.limitations.contains(area) },
            set: { on in
                var areas = store.profile.limitations
                if on {
                    if !areas.contains(area) { areas.append(area) }
                } else {
                    areas.removeAll { $0 == area }
                }
                store.profile.limitations = areas
            }
        )
    }

    private var dumbbellBinding: Binding<Double> {
        Binding(
            get: { store.profile.units.displayWeight(store.profile.maxDumbbellKg).rounded() },
            set: { store.profile.maxDumbbellKg = store.profile.units.kg(fromDisplay: $0) }
        )
    }

    private func showAgain(_ id: String) {
        var profile = store.profile
        profile.excludedExercises.removeAll { $0 == id }
        profile.swapPreferences[id] = nil
        store.profile = profile
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

    private var blockText: String {
        let phase = Periodization.phase(on: Date(), profile: store.profile, history: store.sessions)
        return phase.label
    }
}
