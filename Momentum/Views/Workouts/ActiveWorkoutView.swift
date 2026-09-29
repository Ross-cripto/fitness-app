import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    let onClose: () -> Void

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService

    private struct SetEntry: Identifiable {
        let id = UUID()
        /// Reps, or seconds for timed exercises.
        var value: Int
        /// Weight in the user's display units.
        var weightDisplay: Double
        /// The prescribed load and how it was shown, so an untouched weight logs exactly what was planned
        /// (kg -> rounded lb -> kg would drift).
        var plannedKg: Double = 0
        var initialDisplay: Double = 0
        var done = false
    }

    private struct SetKey: Equatable {
        let exercise: Int
        let set: Int
    }

    @State private var current: Workout
    @State private var entries: [[SetEntry]] = []
    @State private var efforts: [Int: Effort] = [:]
    @State private var rampChecked: Set<String> = []
    @State private var page = 0
    @State private var startedAt = Date()
    @State private var restRemaining = 0
    @State private var holdRemaining = 0
    @State private var holding: SetKey?
    @State private var showEndDialog = false
    @State private var showSummary = false
    @State private var showSwap = false
    @State private var elapsedAtFinish = 0
    @State private var finishedAt = Date()
    @State private var feedback: WorkoutFeedback = .justRight
    @State private var saved = false
    @State private var adaptationMessages: [String] = []
    @State private var healthSaved: Bool?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(workout: Workout, onClose: @escaping () -> Void) {
        _current = State(initialValue: workout)
        self.onClose = onClose
    }

    private var units: UnitSystem { store.profile.units }
    private var items: [PlannedExercise] { current.warmup + current.exercises }
    private var warmupCount: Int { current.warmup.count }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if showSummary {
                summaryView
            } else if !entries.isEmpty && entries.count == items.count {
                playerView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: setup)
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onReceive(ticker) { _ in tick() }
        .onChange(of: page) { _, _ in
            // A running hold belongs to the page it started on.
            holding = nil
            holdRemaining = 0
        }
        .confirmationDialog(L("End workout?"), isPresented: $showEndDialog, titleVisibility: .visible) {
            Button(L("Finish and save")) { finishWorkout() }
            Button(L("Discard workout"), role: .destructive) { onClose() }
            Button(L("Keep going"), role: .cancel) {}
        }
        .sheet(isPresented: $showSwap) {
            if page >= warmupCount, page < items.count {
                SwapSheet(
                    planned: items[page],
                    workout: current,
                    onSwap: { exercise, scope, areas in swapCurrent(with: exercise, scope: scope, areas: areas) },
                    onSkip: { skipCurrent() }
                )
                .environmentObject(store)
            }
        }
    }

    // MARK: Player

    private var playerView: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    exerciseHeader
                    if page >= warmupCount && !items[page].rampSets.isEmpty { rampSection }
                    ForEach(entries[page].indices, id: \.self) { index in
                        setRow(exercise: page, set: index)
                    }
                    if page >= warmupCount && entries[page].contains(where: { $0.done }) { effortSection }
                }
                .padding(20)
            }
            if restRemaining > 0 { restBanner }
            bottomBar
        }
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button { showEndDialog = true } label: {
                    Image(systemName: "xmark")
                        .scaledFont(size: 16, weight: .bold)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .accessibilityLabel(L("End workout"))
                Spacer()
                Text(page < warmupCount
                     ? L("Warm-up {0} of {1}", page + 1, warmupCount)
                     : L("Exercise {0} of {1}", page - warmupCount + 1, current.exercises.count))
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            ProgressBar(value: progress, tint: Theme.pink)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var progress: Double {
        let all = entries.flatMap { $0 }
        guard !all.isEmpty else { return 0 }
        return Double(all.filter { $0.done }.count) / Double(all.count)
    }

    private var exerciseHeader: some View {
        let planned = items[page]
        let exercise = planned.exercise
        let isWarmup = page < warmupCount
        return VStack(alignment: .leading, spacing: 12) {
            FigureCard(exercise: exercise)
                .frame(height: 230)
            VStack(alignment: .leading, spacing: 4) {
                if isWarmup {
                    Text(L("WARM-UP"))
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(Theme.green)
                }
                Text(exercise.name)
                    .scaledFont(size: 26, weight: .bold)
                Text(L("{0} · {1}", exercise.muscle.title, planned.targetLabel))
                    .scaledFont(size: 14, weight: .medium)
                    .foregroundStyle(Color.white.opacity(0.6))
                if let rir = planned.repsInReserve, !isWarmup {
                    Label(Lp(rir, one: "Stop with {0} rep in the tank", other: "Stop with {0} reps in the tank"), systemImage: "gauge.with.dots.needle.33percent")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                if let reason = planned.reason, !isWarmup {
                    Text(reason)
                        .scaledFont(size: 12, weight: .medium)
                        .foregroundStyle(Theme.green.opacity(0.9))
                }
            }
            if !isWarmup {
                Button { showSwap = true } label: {
                    Label(L("Can't do this one?"), systemImage: "arrow.left.arrow.right")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundStyle(Theme.pink)
                }
            }
            DisclosureGroup(L("How to do it")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { pair in
                        Text(verbatim: "\(pair.offset + 1). \(pair.element)")
                            .scaledFont(size: 14)
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    Link(destination: exercise.videoURL) {
                        Label(L("Watch a video on YouTube"), systemImage: "play.rectangle.fill")
                            .scaledFont(size: 14, weight: .semibold)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 6)
            }
            .scaledFont(size: 14, weight: .semibold)
            .tint(Theme.pink)
        }
    }

    private var rampSection: some View {
        let planned = items[page]
        return VStack(alignment: .leading, spacing: 8) {
            Text(L("Warm-up sets (light, not counted)"))
                .scaledFont(size: 13, weight: .semibold)
                .foregroundStyle(Color.white.opacity(0.6))
            ForEach(Array(planned.rampSets.enumerated()), id: \.offset) { pair in
                let key = "\(page)-\(pair.offset)"
                let done = rampChecked.contains(key)
                Button {
                    if done { rampChecked.remove(key) } else { rampChecked.insert(key) }
                } label: {
                    HStack {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(done ? Theme.green : Color.white.opacity(0.4))
                        Text(verbatim: "\(units.formatWeight(pair.element.weightKg)) × \(pair.element.reps)")
                            .scaledFont(size: 15, weight: .medium)
                        Spacer()
                        Text(L("easy"))
                            .scaledFont(size: 12)
                            .foregroundStyle(Color.white.opacity(0.4))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var effortSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("How did {0} feel?", items[page].exercise.name))
                .scaledFont(size: 15, weight: .semibold)
            Text(L("This decides whether the weight or reps go up next time."))
                .scaledFont(size: 12)
                .foregroundStyle(Color.white.opacity(0.55))
            HStack(spacing: 8) {
                ForEach(Effort.allCases) { effort in
                    let selected = efforts[page] == effort
                    Button { efforts[page] = effort } label: {
                        Text(effort.title)
                            .scaledFont(size: 14, weight: .semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? Theme.pink : Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    private func setRow(exercise e: Int, set s: Int) -> some View {
        let exercise = items[e].exercise
        let entry = entries[e][s]
        let isTimed = exercise.kind == .timed
        let isHolding = holding == SetKey(exercise: e, set: s)

        return HStack(spacing: 14) {
            Text(verbatim: "\(s + 1)")
                .scaledFont(size: 15, weight: .bold, design: .rounded)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.1)))

            VStack(alignment: .leading, spacing: 6) {
                Stepper(
                    value: Binding(
                        get: { entries.indices.contains(e) && entries[e].indices.contains(s) ? entries[e][s].value : 1 },
                        set: { if entries.indices.contains(e), entries[e].indices.contains(s) { entries[e][s].value = $0 } }
                    ),
                    in: isTimed ? 5...300 : 1...100,
                    step: isTimed ? 5 : 1
                ) {
                    Text(isTimed ? L("{0} sec", entry.value) : Lp(entry.value, one: "{0} rep", other: "{0} reps"))
                        .scaledFont(size: 16, weight: .semibold)
                }
                if exercise.isLoaded {
                    Stepper(
                        value: weightBinding(e, s),
                        in: 0...1100,
                        step: units.weightStep
                    ) {
                        Text(weightText(entry.weightDisplay))
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }

            Button { toggle(e, s) } label: {
                ZStack {
                    Circle().fill(entry.done ? Theme.green : Color.white.opacity(0.12))
                    if isHolding {
                        Text(verbatim: "\(holdRemaining)")
                            .scaledFont(size: 16, weight: .bold, design: .rounded)
                    } else {
                        Image(systemName: entry.done ? "checkmark" : (isTimed ? "play.fill" : "checkmark"))
                            .scaledFont(size: 16, weight: .bold)
                            .foregroundStyle(entry.done ? Color.white : Color.white.opacity(0.6))
                    }
                }
                .frame(width: 46, height: 46)
            }
            .accessibilityLabel(entry.done ? L("Undo set {0}", s + 1) : L("Complete set {0}", s + 1))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private var restBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .foregroundStyle(Theme.green)
            Text(L("Rest {0}", formatClock(restRemaining)))
                .scaledFont(size: 18, weight: .bold, design: .rounded)
                .monospacedDigit()
            Spacer()
            Button(L("+15s")) { restRemaining += 15 }
                .scaledFont(size: 14, weight: .semibold)
            Button(L("Skip")) { restRemaining = 0 }
                .scaledFont(size: 14, weight: .semibold)
                .foregroundStyle(Theme.pink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
    }

    private var bottomBar: some View {
        let isLast = page == items.count - 1
        let allDone = entries[page].allSatisfy { $0.done }
        return HStack {
            if page > 0 {
                Button(L("Previous")) { page -= 1 }
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Spacer()
            Button(isLast ? L("Finish") : (page + 1 == warmupCount ? L("Start workout") : L("Next exercise"))) {
                if isLast { finishWorkout() } else { page += 1 }
            }
            .buttonStyle(PillButtonStyle(tint: allDone ? Theme.pink : Color(white: 0.3)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Summary

    /// Only the working exercises count toward the session (warm-up drills and ramp sets do not).
    private var workingEntries: [[SetEntry]] { Array(entries.dropFirst(warmupCount)) }
    private var completedSets: Int { workingEntries.flatMap { $0 }.filter { $0.done }.count }
    private var plannedSets: Int { workingEntries.flatMap { $0 }.count }

    private var summaryView: some View {
        let duration = max(60, elapsedAtFinish)
        let calories = estimateCalories(duration: duration)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: completedSets == 0 ? "moon.zzz.fill" : "checkmark.seal.fill")
                    .scaledFont(size: 44)
                    .foregroundStyle(completedSets == 0 ? Color.gray : Theme.green)
                    .padding(.top, 40)

                Text(completedSets == 0 ? L("No sets logged") : L("Workout complete"))
                    .scaledFont(size: 34, weight: .bold)

                HStack(spacing: 22) {
                    StatPill(symbol: "flame.fill", value: "\(completedSets == 0 ? 0 : calories)", unit: L("cal"), tint: Theme.pink, onDark: true)
                    StatPill(symbol: "timer", value: "\(duration / 60)", unit: L("min"), tint: Theme.green, onDark: true)
                    StatPill(symbol: "checkmark.circle.fill", value: "\(completedSets)/\(plannedSets)", unit: L("sets"), tint: Theme.amber, onDark: true)
                }

                if completedSets == 0 {
                    Button(L("Close")) { onClose() }
                        .buttonStyle(PillButtonStyle())
                } else if saved {
                    if healthSaved == true {
                        Label(L("Saved to Apple Health"), systemImage: "heart.fill")
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundStyle(Theme.pink)
                    } else if healthSaved == false {
                        Label(L("Couldn't save to Apple Health. Check Settings → Health → Data Access."), systemImage: "exclamationmark.triangle")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    ForEach(adaptationMessages, id: \.self) { message in
                        Label(message, systemImage: "wand.and.stars")
                            .scaledFont(size: 15, weight: .medium)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
                    }
                    Button(L("Done")) { onClose() }
                        .buttonStyle(PillButtonStyle())
                } else {
                    Text(L("How did the whole workout feel?"))
                        .scaledFont(size: 17, weight: .semibold)
                    Text(L("Two sessions in a row that feel too easy or too hard change your plan."))
                        .scaledFont(size: 14)
                        .foregroundStyle(Color.white.opacity(0.6))

                    HStack(spacing: 10) {
                        ForEach(WorkoutFeedback.allCases) { option in
                            Button { feedback = option } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: option.symbol).scaledFont(size: 22)
                                    Text(option.title).scaledFont(size: 13, weight: .semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(feedback == option ? Theme.pink : Color.white.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    HStack(spacing: 16) {
                        Button(L("Save workout")) { save(duration: duration, calories: calories) }
                            .buttonStyle(PillButtonStyle())
                        Button(L("Discard")) { onClose() }
                            .scaledFont(size: 15, weight: .semibold)
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Actions

    private func loggedKg(_ entry: SetEntry) -> Double {
        abs(entry.weightDisplay - entry.initialDisplay) < 0.001 ? entry.plannedKg : units.kg(fromDisplay: entry.weightDisplay)
    }

    /// Changing a set's weight carries to the sets after it that are not done yet, so one heavier set does not
    /// make the rest of the exercise look like skipped sets.
    private func weightBinding(_ e: Int, _ s: Int) -> Binding<Double> {
        Binding(
            get: { entries.indices.contains(e) && entries[e].indices.contains(s) ? entries[e][s].weightDisplay : 0 },
            set: { newValue in
                guard entries.indices.contains(e), entries[e].indices.contains(s) else { return }
                entries[e][s].weightDisplay = newValue
                for later in (s + 1)..<max(s + 1, entries[e].count) where !entries[e][later].done {
                    entries[e][later].weightDisplay = newValue
                }
            }
        )
    }

    private func makeEntries(for planned: PlannedExercise) -> [SetEntry] {
        let step = units.weightStep
        let display = units.displayWeight(planned.weightKg ?? 0)
        let rounded = (display / step).rounded() * step
        return (0..<planned.sets).map { _ in
            SetEntry(value: planned.target, weightDisplay: rounded, plannedKg: planned.weightKg ?? 0, initialDisplay: rounded)
        }
    }

    private func setup() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard entries.isEmpty else { return }
        entries = items.map { makeEntries(for: $0) }
        startedAt = Date()
    }

    private func swapCurrent(with exercise: Exercise, scope: SwapScope, areas: [BodyArea]) {
        let mainIndex = page - warmupCount
        guard mainIndex >= 0, mainIndex < current.exercises.count else { return }
        let original = current.exercises[mainIndex]
        var replacement = PlanGenerator.replan(
            exercise,
            profile: store.profile,
            history: store.sessions,
            sets: original.sets,
            on: current.date ?? Date(),
            readiness: store.todaysReadiness
        )
        let prefix = L("Swapped in for {0}.", original.exercise.name)
        replacement.reason = replacement.reason.map { "\(prefix) \($0)" } ?? prefix
        current.exercises[mainIndex] = replacement
        entries[page] = makeEntries(for: replacement)
        efforts[page] = nil
        rampChecked = rampChecked.filter { !$0.hasPrefix("\(page)-") }
        holding = nil
        holdRemaining = 0
        store.rememberSwap(original: original.exercise, replacement: exercise, scope: scope, protecting: areas)
        if !areas.isEmpty {
            // Newly protected areas apply to the exercises still ahead in this workout.
            let blocked = current.exercises.indices.filter {
                $0 > mainIndex && !PlanGenerator.isAllowed(current.exercises[$0].exercise, profile: store.profile)
            }
            for index in blocked.reversed() {
                current.exercises.remove(at: index)
                entries.remove(at: index + warmupCount)
            }
            efforts = efforts.filter { $0.key <= page }
        }
    }

    private func skipCurrent() {
        let mainIndex = page - warmupCount
        guard mainIndex >= 0, mainIndex < current.exercises.count, current.exercises.count > 1 else { return }
        current.exercises.remove(at: mainIndex)
        entries.remove(at: page)
        var shifted: [Int: Effort] = [:]
        for (key, value) in efforts where key != page { shifted[key > page ? key - 1 : key] = value }
        efforts = shifted
        rampChecked = []
        holding = nil
        holdRemaining = 0
        page = min(page, items.count - 1)
    }

    private func toggle(_ e: Int, _ s: Int) {
        if entries[e][s].done {
            entries[e][s].done = false
            return
        }
        let key = SetKey(exercise: e, set: s)
        if items[e].exercise.kind == .timed {
            if holding == key {
                holding = nil
                holdRemaining = 0
            } else {
                holding = key
                holdRemaining = entries[e][s].value
                restRemaining = 0
            }
            return
        }
        entries[e][s].done = true
        startRest(after: e, set: s)
        impact()
    }

    private func startRest(after e: Int, set s: Int) {
        let isFinalSet = s == entries[e].count - 1 && e == entries.count - 1
        restRemaining = isFinalSet ? 0 : items[e].restSeconds
    }

    private func tick() {
        if holdRemaining > 0 {
            holdRemaining -= 1
            if holdRemaining == 0, let key = holding, key.exercise < entries.count, key.set < entries[key.exercise].count {
                entries[key.exercise][key.set].done = true
                holding = nil
                startRest(after: key.exercise, set: key.set)
                notify()
            }
        } else if restRemaining > 0 {
            restRemaining -= 1
            if restRemaining == 0 { notify() }
        }
    }

    private func finishWorkout() {
        finishedAt = Date()
        elapsedAtFinish = Int(finishedAt.timeIntervalSince(startedAt))
        holding = nil
        holdRemaining = 0
        restRemaining = 0
        showSummary = true
    }

    private func estimateCalories(duration: Int) -> Int {
        var weighted = 0.0
        var sets = 0
        for (index, list) in entries.enumerated() {
            let done = list.filter { $0.done }.count
            weighted += items[index].exercise.met * Double(done)
            sets += done
        }
        let met = sets > 0 ? max(3.5, weighted / Double(sets)) : 3.5
        // Rest periods burn less than the working MET, so scale down a little.
        return Int((0.85 * met * store.profile.weightKg * Double(duration) / 3600).rounded())
    }

    private func save(duration: Int, calories: Int) {
        var logs: [ExerciseLog] = []
        for (index, list) in entries.enumerated() where index >= warmupCount {
            let done = list.filter { $0.done }
            if done.isEmpty { continue }
            let planned = items[index]
            let exercise = planned.exercise
            let sets = done.map { entry in
                SetLog(
                    reps: exercise.kind == .reps ? entry.value : 0,
                    weightKg: exercise.isLoaded ? loggedKg(entry) : 0,
                    seconds: exercise.kind == .timed ? entry.value : 0
                )
            }
            logs.append(ExerciseLog(
                exerciseID: exercise.id,
                targetSets: planned.sets,
                target: planned.target,
                sets: sets,
                repMin: planned.repMin,
                repMax: planned.repMax,
                effort: efforts[index]
            ))
        }

        let session = WorkoutSession(
            date: finishedAt,
            title: current.title,
            durationSeconds: duration,
            calories: calories,
            plannedSets: plannedSets,
            completedSets: completedSets,
            logs: logs,
            feedback: feedback,
            readiness: store.todaysReadiness,
            wasDeload: current.phase?.isDeload
        )
        adaptationMessages = store.record(session)
        saved = true
        if store.profile.healthSync {
            Task { @MainActor in healthSaved = await health.saveWorkout(session) }
        }
    }

    private func weightText(_ value: Double) -> String {
        return "\(Loc.number(value)) \(units.weightLabel)"
    }

    private func impact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func notify() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
