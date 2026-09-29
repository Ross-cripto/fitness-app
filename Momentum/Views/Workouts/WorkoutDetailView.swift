import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss

    @State private var current: Workout
    @State private var showPlayer = false
    @State private var infoExercise: Exercise?
    @State private var swapTarget: PlannedExercise?

    init(workout: Workout) {
        _current = State(initialValue: workout)
    }

    private var units: UnitSystem { store.profile.units }

    /// Readiness only applies to today's scheduled workout.
    private var canSetReadiness: Bool {
        guard let date = current.date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 210)

                    HStack(spacing: 20) {
                        StatPill(
                            symbol: "flame.fill",
                            value: "\(current.calories(weightKg: store.profile.weightKg))",
                            unit: "cal", tint: Theme.pink, large: false, onDark: true
                        )
                        StatPill(
                            symbol: "timer",
                            value: "\(current.minutes)",
                            unit: "min", tint: Theme.green, large: false, onDark: true
                        )
                    }

                    Text(current.title)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 10)
                    HStack(spacing: 8) {
                        Text(current.subtitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                        if let phase = current.phase {
                            Text(phase.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(phase.isDeload ? Theme.amber : Theme.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.1)))
                        }
                    }
                    .padding(.bottom, 12)

                    if let note = current.note {
                        Label(note, systemImage: "info.circle.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)))
                            .padding(.bottom, 12)
                    }

                    if canSetReadiness { readinessPicker }

                    if !current.warmup.isEmpty {
                        sectionLabel("Warm-up · \(current.warmup.count) drills")
                        Text(current.warmup.map { $0.exercise.name }.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .padding(.bottom, 14)
                    }

                    sectionLabel("Workout")
                    VStack(spacing: 16) {
                        ForEach(current.exercises) { planned in
                            row(planned)
                        }
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 20)
            }

            Button("Start Workout") { showPlayer = true }
                .buttonStyle(PillButtonStyle())
                .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPlayer) {
            ActiveWorkoutView(workout: current) {
                showPlayer = false
                dismiss()
            }
            .environmentObject(store)
            .environmentObject(health)
        }
        .sheet(item: $infoExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
                .environmentObject(store)
        }
        .sheet(item: $swapTarget) { planned in
            SwapSheet(
                planned: planned,
                workout: current,
                onSwap: { exercise, scope, areas in swap(planned, with: exercise, scope: scope, areas: areas) },
                onSkip: { skip(planned) }
            )
            .environmentObject(store)
        }
    }

    // MARK: Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.6))
            .padding(.bottom, 8)
    }

    private var readinessPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("How do you feel today?")
            HStack(spacing: 8) {
                ForEach(Readiness.allCases) { option in
                    let selected = store.todaysReadiness == option
                    Button {
                        store.setReadiness(option)
                        if let date = current.date, let regenerated = store.workout(on: date) {
                            current = regenerated
                        }
                    } label: {
                        Label(option.title, systemImage: option.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.7))
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(selected ? Theme.pink : Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 14)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Color.black
            LinearGradient(colors: current.theme.colors, startPoint: .top, endPoint: .bottom)
                .frame(height: 520)
                .frame(maxHeight: .infinity, alignment: .top)
            Image(systemName: current.theme.symbol)
                .font(.system(size: 170))
                .foregroundStyle(Color.white.opacity(0.12))
                .padding(.top, 90)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 30)
            LinearGradient(colors: [.clear, .black], startPoint: .init(x: 0.5, y: 0.2), endPoint: .init(x: 0.5, y: 0.55))
        }
        .ignoresSafeArea()
    }

    private func row(_ planned: PlannedExercise) -> some View {
        let exercise = planned.exercise
        let calories = Int(planned.calories(weightKg: store.profile.weightKg).rounded())
        let minutes = max(1, Int((Double(planned.totalSeconds) / 60).rounded()))

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    infoExercise = exercise
                } label: {
                    HStack(spacing: 12) {
                        FigureThumb(exercise: exercise, animated: true)
                            .frame(width: 76, height: 56)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            Text(detailLine(planned))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.6))
                            Text("\(minutes) min · \(calories) cal")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                        Spacer(minLength: 4)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    swapTarget = planned
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Can't do \(exercise.name)? Swap it")
            }
            if let reason = planned.reason {
                Text(reason)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.green.opacity(0.9))
                    .padding(.leading, 88)
            }
        }
    }

    private func detailLine(_ planned: PlannedExercise) -> String {
        var text = planned.targetLabel
        if let kg = planned.weightKg {
            text += " · \(units.formatWeight(kg))"
        }
        return text
    }

    // MARK: Swapping

    private func swap(_ planned: PlannedExercise, with exercise: Exercise, scope: SwapScope, areas: [BodyArea]) {
        guard let index = current.exercises.firstIndex(where: { $0.id == planned.id }) else { return }
        var replacement = PlanGenerator.replan(
            exercise,
            profile: store.profile,
            history: store.sessions,
            sets: planned.sets,
            on: current.date ?? Date(),
            readiness: store.todaysReadiness
        )
        let prefix = "Swapped in for \(planned.exercise.name)."
        replacement.reason = replacement.reason.map { "\(prefix) \($0)" } ?? prefix
        current.exercises[index] = replacement
        store.rememberSwap(original: planned.exercise, replacement: exercise, scope: scope, protecting: areas)
    }

    private func skip(_ planned: PlannedExercise) {
        guard current.exercises.count > 1 else { return }
        current.exercises.removeAll { $0.id == planned.id }
    }
}
