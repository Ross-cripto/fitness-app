import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var confirmRePlace = false

    private enum ExportKind { case backup, csv }
    @State private var exportKind: ExportKind?
    @State private var exportDocument = DataFileDocument(data: Data())
    @State private var showImporter = false
    @State private var pendingRestore: (data: Data, workouts: Int, weights: Int)?
    @State private var backupMessage: String?

    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(L("Language"), selection: $store.profile.language) {
                        Text(L("Automatic")).tag(Optional<AppLanguage>.none)
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.nativeName).tag(Optional(language))
                        }
                    }
                } footer: {
                    Text(L("Changes the language of the whole app, including exercise names and instructions."))
                }

                Section(L("Profile")) {
                    TextField(L("Name"), text: $store.profile.name)
                    Picker(L("Goal"), selection: $store.profile.goal) {
                        ForEach(Goal.allCases) { Text($0.title).tag($0) }
                    }
                    Picker(L("Level"), selection: $store.profile.level) {
                        ForEach(FitnessLevel.allCases) { Text($0.title).tag($0) }
                    }
                    Picker(L("Equipment"), selection: $store.profile.equipment) {
                        ForEach(Equipment.allCases) { Text($0.title).tag($0) }
                    }
                    if store.profile.equipment == .dumbbells {
                        Stepper(value: dumbbellBinding, in: 0...130, step: 1) {
                            Text(store.profile.maxDumbbellKg == 0
                                 ? L("Heaviest dumbbell: no limit")
                                 : L("Heaviest dumbbell: {0} {1}", Int(dumbbellBinding.wrappedValue), store.profile.units.weightLabel))
                        }
                    }
                }

                Section {
                    HStack(spacing: 6) {
                        ForEach(Self.weekdayOrder, id: \.self) { weekday in
                            let on = activeWeekdays.contains(weekday)
                            Button { toggle(weekday) } label: {
                                Text(Loc.calendar.veryShortWeekdaySymbols[weekday - 1])
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(on ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? Theme.pink : Color.primary.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Loc.calendar.standaloneWeekdaySymbols[weekday - 1])
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    Picker(L("Session length"), selection: $store.profile.sessionMinutes) {
                        ForEach([20, 30, 45, 60, 90], id: \.self) { Text(L("{0} min", $0)).tag($0) }
                    }
                } header: {
                    Text(L("Schedule"))
                } footer: {
                    Text(Lp(activeWeekdays.count,
                            one: "{0} day a week. Changing days re-plans upcoming workouts.",
                            other: "{0} days a week. Changing days re-plans upcoming workouts."))
                }

                Section {
                    ForEach(BodyArea.allCases) { area in
                        Toggle(area.title, isOn: binding(for: area))
                    }
                    Toggle(L("Low impact only (no jumping)"), isOn: $store.profile.lowImpactOnly)
                } header: {
                    Text(L("Protect"))
                } footer: {
                    Text(L("Exercises that load these areas are never picked. Not medical advice: if something hurts, see a professional."))
                }

                Section(L("Body")) {
                    Picker(L("Sex"), selection: $store.profile.sex) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                    Picker(L("Units"), selection: $store.profile.units) {
                        ForEach(UnitSystem.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(value: $store.profile.age, in: 14...90) {
                        Text(L("Age: {0}", store.profile.age))
                    }
                    LabeledContent(L("Weight"), value: store.profile.units.formatWeight(store.profile.weightKg))
                }

                if !store.profile.excludedExercises.isEmpty || !store.profile.swapPreferences.isEmpty {
                    Section {
                        ForEach(store.profile.excludedExercises, id: \.self) { id in
                            HStack {
                                Text(ExerciseLibrary.exercise(id).name)
                                Spacer()
                                Button(L("Show again")) { showAgain(id) }
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        ForEach(store.profile.swapPreferences.keys.sorted(), id: \.self) { id in
                            if !store.profile.excludedExercises.contains(id), let replacement = store.profile.swapPreferences[id] {
                                HStack {
                                    Text(L("{0} → {1}", ExerciseLibrary.exercise(id).name, ExerciseLibrary.exercise(replacement).name))
                                        .font(.system(size: 14))
                                    Spacer()
                                    Button(L("Undo")) { store.profile.swapPreferences[id] = nil }
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    } header: {
                        Text(L("Your swaps"))
                    } footer: {
                        Text(L("Exercises you hid or replaced from a workout."))
                    }
                }

                Section {
                    Toggle(L("Sync with Apple Health"), isOn: healthBinding)
                        .tint(Theme.pink)
                        .disabled(!HealthService.isAvailable)
                    if let message = health.lastError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text(L("Apple Health"))
                } footer: {
                    Text(L("Saves finished workouts and body weight to Health, and reads your steps and active energy. Data stays on this device and in your Health app. You can change permissions any time in Settings → Health → Data Access & Devices."))
                }

                Section {
                    LabeledContent(L("Difficulty offset"), value: intensityText)
                    LabeledContent(L("Training block"), value: blockText)
                    Button(L("Re-place me from my onboarding answers")) { confirmRePlace = true }
                } header: {
                    Text(L("Adaptive plan"))
                } footer: {
                    Text(L("Your level, exercise steps and difficulty change on their own from how you train. Re-placing clears that history and starts again from your answers."))
                }

                Section {
                    Button(L("Back up my data")) { export(.backup) }
                    Button(L("Restore from a backup…")) { showImporter = true }
                    Button(L("Export workout history (CSV)")) { export(.csv) }
                } header: {
                    Text(L("Your data"))
                } footer: {
                    Text(L("A backup is a plain JSON file you can save anywhere (iCloud Drive, email, another phone). The CSV has one row per set, for spreadsheets."))
                }

                Section {
                    Button(L("Delete all data"), role: .destructive) { confirmReset = true }
                } footer: {
                    Text(L("Momentum is free and works fully offline. All data is stored only on this device."))
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }
            .confirmationDialog(L("Delete all workouts, weights and settings?"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L("Delete everything"), role: .destructive) {
                    store.resetAll()
                    dismiss()
                }
                Button(L("Cancel"), role: .cancel) {}
            }
            .fileExporter(
                isPresented: Binding(get: { exportKind != nil }, set: { if !$0 { exportKind = nil } }),
                document: exportDocument,
                contentType: exportKind == .csv ? .commaSeparatedText : .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure = result { backupMessage = L("Couldn't save the file.") }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                prepareRestore(result)
            }
            .confirmationDialog(
                L("Replace all your data with this backup?"),
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                titleVisibility: .visible
            ) {
                Button(L("Replace my data"), role: .destructive) { restorePending() }
                Button(L("Cancel"), role: .cancel) { pendingRestore = nil }
            } message: {
                if let pending = pendingRestore {
                    Text(L("Workouts in this backup: {0}. Weigh-ins: {1}.", pending.workouts, pending.weights)
                         + " " + L("Your current data will be replaced; a copy is kept on this device in case you change your mind."))
                }
            }
            .alert(L("Backup"), isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
                Button(L("OK"), role: .cancel) {}
            } message: {
                Text(backupMessage ?? "")
            }
            .confirmationDialog(L("Reset your adaptive plan?"), isPresented: $confirmRePlace, titleVisibility: .visible) {
                Button(L("Re-place me")) { store.resetAdaptation() }
                Button(L("Cancel"), role: .cancel) {}
            }
        }
    }

    // MARK: Backup

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date())
        return exportKind == .csv ? "momentum-history-\(day)" : "momentum-backup-\(day)"
    }

    private func export(_ kind: ExportKind) {
        switch kind {
        case .backup:
            guard let data = try? store.exportBackup() else {
                backupMessage = L("Couldn't save the file.")
                return
            }
            exportDocument = DataFileDocument(data: data)
        case .csv:
            exportDocument = DataFileDocument(data: Data(store.exportCSV().utf8))
        }
        exportKind = kind
    }

    private func prepareRestore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            backupMessage = L("Couldn't read that file.")
            return
        }
        do {
            let contents = try Backup.read(data)
            pendingRestore = (data, contents.sessions.count, contents.weights.count)
        } catch BackupError.newerVersion {
            backupMessage = L("This backup was made by a newer version of Momentum. Update the app and try again.")
        } catch {
            backupMessage = L("That file is not a Momentum backup.")
        }
    }

    private func restorePending() {
        guard let pending = pendingRestore else { return }
        pendingRestore = nil
        do {
            try store.restore(from: pending.data)
            backupMessage = L("Backup restored.")
        } catch {
            backupMessage = L("That file is not a Momentum backup.")
        }
    }

    // MARK: Helpers

    /// The days actually used for planning (an old save with no days uses the engine's default).
    private var activeWeekdays: [Int] { PlanGenerator.weekdays(for: store.profile) }

    private func toggle(_ weekday: Int) {
        var days = activeWeekdays
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
        if value == 0 { return L("Baseline") }
        return value > 0 ? L("+{0} tougher", value) : L("{0} easier", value)
    }

    private var blockText: String {
        let phase = Periodization.phase(on: Date(), profile: store.profile, history: store.sessions)
        return phase.label
    }
}
