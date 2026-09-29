import SwiftUI
import UIKit

struct ActiveWorkoutView: View {
    let workout: Workout
    let onClose: () -> Void

    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService

    private struct SetEntry: Identifiable {
        let id = UUID()
        /// Reps, or seconds for timed exercises.
        var value: Int
        /// Weight in the user's display units.
        var weightDisplay: Double
        var done = false
    }

    private struct SetKey: Equatable {
        let exercise: Int
        let set: Int
    }

    @State private var entries: [[SetEntry]] = []
    @State private var page = 0
    @State private var startedAt = Date()
    @State private var restRemaining = 0
    @State private var holdRemaining = 0
    @State private var holding: SetKey?
    @State private var showEndDialog = false
    @State private var showSummary = false
    @State private var elapsedAtFinish = 0
    @State private var finishedAt = Date()
    @State private var healthSaved: Bool?
    @State private var feedback: WorkoutFeedback = .justRight
    @State private var saved = false
    @State private var adaptationMessage: String?

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var units: UnitSystem { store.profile.units }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if showSummary {
                summaryView
            } else if !entries.isEmpty {
                playerView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: setup)
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onReceive(ticker) { _ in tick() }
        .confirmationDialog("End workout?", isPresented: $showEndDialog, titleVisibility: .visible) {
            Button("Finish and save") { finishWorkout() }
            Button("Discard workout", role: .destructive) { onClose() }
            Button("Keep going", role: .cancel) {}
        }
    }

    // MARK: Player

    private var playerView: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    exerciseHeader
                    ForEach(entries[page].indices, id: \.self) { index in
                        setRow(exercise: page, set: index)
                    }
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
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .accessibilityLabel("End workout")
                Spacer()
                Text("Exercise \(page + 1) of \(workout.exercises.count)")
                    .font(.system(size: 14, weight: .semibold))
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
        let planned = workout.exercises[page]
        let exercise = planned.exercise
        return VStack(alignment: .leading, spacing: 12) {
            FigureCard(exercise: exercise)
                .frame(height: 230)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 26, weight: .bold))
                Text("\(exercise.muscle.title) · \(planned.targetLabel)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            DisclosureGroup("How to do it") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(exercise.steps.enumerated()), id: \.offset) { pair in
                        Text("\(pair.offset + 1). \(pair.element)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    Link(destination: exercise.videoURL) {
                        Label("Watch a video on YouTube", systemImage: "play.rectangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 6)
            }
            .font(.system(size: 14, weight: .semibold))
            .tint(Theme.pink)
        }
    }

    private func setRow(exercise e: Int, set s: Int) -> some View {
        let exercise = workout.exercises[e].exercise
        let entry = entries[e][s]
        let isTimed = exercise.kind == .timed
        let isHolding = holding == SetKey(exercise: e, set: s)

        return HStack(spacing: 14) {
            Text("\(s + 1)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.1)))

            VStack(alignment: .leading, spacing: 6) {
                Stepper(
                    value: $entries[e][s].value,
                    in: isTimed ? 5...300 : 1...100,
                    step: isTimed ? 5 : 1
                ) {
                    Text(isTimed ? "\(entry.value) sec" : "\(entry.value) reps")
                        .font(.system(size: 16, weight: .semibold))
                }
                if exercise.isLoaded {
                    Stepper(
                        value: $entries[e][s].weightDisplay,
                        in: 0...1100,
                        step: units.weightStep
                    ) {
                        Text(weightText(entry.weightDisplay))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }

            Button { toggle(e, s) } label: {
                ZStack {
                    Circle().fill(entry.done ? Theme.green : Color.white.opacity(0.12))
                    if isHolding {
                        Text("\(holdRemaining)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    } else {
                        Image(systemName: entry.done ? "checkmark" : (isTimed ? "play.fill" : "checkmark"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(entry.done ? Color.white : Color.white.opacity(0.6))
                    }
                }
                .frame(width: 46, height: 46)
            }
            .accessibilityLabel(entry.done ? "Undo set \(s + 1)" : "Complete set \(s + 1)")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
    }

    private var restBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .foregroundStyle(Theme.green)
            Text("Rest  \(formatClock(restRemaining))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
            Spacer()
            Button("+15s") { restRemaining += 15 }
                .font(.system(size: 14, weight: .semibold))
            Button("Skip") { restRemaining = 0 }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.pink)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
    }

    private var bottomBar: some View {
        let isLast = page == workout.exercises.count - 1
        let allDone = entries[page].allSatisfy { $0.done }
        return HStack {
            if page > 0 {
                Button("Previous") { page -= 1 }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            Spacer()
            Button(isLast ? "Finish" : "Next exercise") {
                if isLast { finishWorkout() } else { page += 1 }
            }
            .buttonStyle(PillButtonStyle(tint: allDone ? Theme.pink : Color(white: 0.3)))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: Summary

    private var completedSets: Int { entries.flatMap { $0 }.filter { $0.done }.count }
    private var plannedSets: Int { entries.flatMap { $0 }.count }

    private var summaryView: some View {
        let duration = max(60, elapsedAtFinish)
        let calories = estimateCalories(duration: duration)

        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: completedSets == 0 ? "moon.zzz.fill" : "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(completedSets == 0 ? Color.gray : Theme.green)
                    .padding(.top, 40)

                Text(completedSets == 0 ? "No sets logged" : "Workout complete")
                    .font(.system(size: 34, weight: .bold))

                HStack(spacing: 22) {
                    StatPill(symbol: "flame.fill", value: "\(completedSets == 0 ? 0 : calories)", unit: "cal", tint: Theme.pink, onDark: true)
                    StatPill(symbol: "timer", value: "\(duration / 60)", unit: "min", tint: Theme.green, onDark: true)
                    StatPill(symbol: "checkmark.circle.fill", value: "\(completedSets)/\(plannedSets)", unit: "sets", tint: Theme.amber, onDark: true)
                }

                if completedSets == 0 {
                    Button("Close") { onClose() }
                        .buttonStyle(PillButtonStyle())
                } else if saved {
                    if healthSaved == true {
                        Label("Saved to Apple Health", systemImage: "heart.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.pink)
                    } else if healthSaved == false {
                        Label("Couldn't save to Apple Health. Check Settings → Health → Data Access.", systemImage: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    if let message = adaptationMessage {
                        Label(message, systemImage: "wand.and.stars")
                            .font(.system(size: 16, weight: .medium))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.08)))
                    }
                    Button("Done") { onClose() }
                        .buttonStyle(PillButtonStyle())
                } else {
                    Text("How did that feel?")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Your answer tunes the next workouts: sets, reps, rest and weights.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.6))

                    HStack(spacing: 10) {
                        ForEach(WorkoutFeedback.allCases) { option in
                            Button { feedback = option } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: option.symbol).font(.system(size: 22))
                                    Text(option.title).font(.system(size: 13, weight: .semibold))
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
                        Button("Save workout") { save(duration: duration, calories: calories) }
                            .buttonStyle(PillButtonStyle())
                        Button("Discard") { onClose() }
                            .font(.system(size: 15, weight: .semibold))
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

    private func setup() {
        UIApplication.shared.isIdleTimerDisabled = true
        guard entries.isEmpty else { return }
        let units = store.profile.units
        let step = units.weightStep
        entries = workout.exercises.map { planned in
            let display = units.displayWeight(planned.weightKg ?? 0)
            let rounded = (display / step).rounded() * step
            return (0..<planned.sets).map { _ in SetEntry(value: planned.target, weightDisplay: rounded) }
        }
        startedAt = Date()
    }

    private func toggle(_ e: Int, _ s: Int) {
        if entries[e][s].done {
            entries[e][s].done = false
            return
        }
        let key = SetKey(exercise: e, set: s)
        if workout.exercises[e].exercise.kind == .timed {
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
        restRemaining = isFinalSet ? 0 : workout.exercises[e].restSeconds
    }

    private func tick() {
        if holdRemaining > 0 {
            holdRemaining -= 1
            if holdRemaining == 0, let key = holding {
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
            weighted += workout.exercises[index].exercise.met * Double(done)
            sets += done
        }
        let met = sets > 0 ? max(3.5, weighted / Double(sets)) : 3.5
        // Rest periods burn less than the working MET, so scale down a little.
        return Int((0.85 * met * store.profile.weightKg * Double(duration) / 3600).rounded())
    }

    private func save(duration: Int, calories: Int) {
        var logs: [ExerciseLog] = []
        for (index, list) in entries.enumerated() {
            let done = list.filter { $0.done }
            if done.isEmpty { continue }
            let planned = workout.exercises[index]
            let exercise = planned.exercise
            let sets = done.map { entry in
                SetLog(
                    reps: exercise.kind == .reps ? entry.value : 0,
                    weightKg: exercise.isLoaded ? units.kg(fromDisplay: entry.weightDisplay) : 0,
                    seconds: exercise.kind == .timed ? entry.value : 0
                )
            }
            logs.append(ExerciseLog(exerciseID: exercise.id, targetSets: planned.sets, target: planned.target, sets: sets))
        }

        let session = WorkoutSession(
            date: finishedAt,
            title: workout.title,
            durationSeconds: duration,
            calories: calories,
            plannedSets: plannedSets,
            completedSets: completedSets,
            logs: logs,
            feedback: feedback
        )
        adaptationMessage = store.record(session)
        saved = true
        if store.profile.healthSync {
            Task { @MainActor in healthSaved = await health.saveWorkout(session) }
        }
    }

    private func weightText(_ value: Double) -> String {
        let text = value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
        return "\(text) \(units.weightLabel)"
    }

    private func impact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func notify() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
