import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var current: Workout
    @State private var showPlayer = false
    @State private var infoExercise: Exercise?

    init(workout: Workout) {
        _current = State(initialValue: workout)
    }

    private var units: UnitSystem { store.profile.units }

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
                    Text(current.subtitle)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .padding(.bottom, 14)

                    Text("Set 1")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.bottom, 8)

                    VStack(spacing: 14) {
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
        }
        .sheet(item: $infoExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
                .environmentObject(store)
        }
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

        return HStack(spacing: 12) {
            Button {
                infoExercise = exercise
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        LinearGradient(colors: exercise.muscle.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: exercise.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .frame(width: 76, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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

            swapMenu(for: planned)
        }
    }

    private func detailLine(_ planned: PlannedExercise) -> String {
        var text = planned.targetLabel
        if let kg = planned.weightKg {
            text += " · \(units.formatWeight(kg))"
        }
        return text
    }

    private func swapMenu(for planned: PlannedExercise) -> some View {
        let options = PlanGenerator.alternatives(for: planned, in: current, profile: store.profile)
        return Menu {
            ForEach(options) { option in
                Button(option.name) { swap(planned, with: option) }
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .disabled(options.isEmpty)
        .opacity(options.isEmpty ? 0.3 : 1)
        .accessibilityLabel("Swap exercise")
    }

    private func swap(_ planned: PlannedExercise, with exercise: Exercise) {
        guard let index = current.exercises.firstIndex(where: { $0.id == planned.id }) else { return }
        current.exercises[index] = PlanGenerator.replan(exercise, profile: store.profile, history: store.sessions)
    }
}
