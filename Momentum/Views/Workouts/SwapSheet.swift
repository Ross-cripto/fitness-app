import SwiftUI

/// "I can't do this one": pick why, see fitting alternatives, choose how long the swap should last.
struct SwapSheet: View {
    let planned: PlannedExercise
    let workout: Workout
    /// Called with the chosen replacement, how long to keep the swap, and body areas to protect from now on.
    let onSwap: (Exercise, SwapScope, [BodyArea]) -> Void
    /// Called when the person would rather skip the exercise for today.
    let onSkip: () -> Void

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var reason: SwapReason?
    @State private var painAreas: Set<BodyArea> = []
    @State private var protectFromNowOn = true
    @State private var chosen: Alternative?
    @State private var scope: SwapScope = .today

    private var exercise: Exercise { planned.exercise }

    private var suggestions: [Alternative] {
        guard let reason = reason else { return [] }
        return Alternatives.suggest(
            for: planned,
            in: workout,
            reason: reason,
            profile: store.profile,
            painAreas: Array(painAreas).sorted { $0.rawValue < $1.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SwapReason.allCases) { option in
                        Button {
                            reason = option
                            chosen = nil
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: option.symbol)
                                    .frame(width: 26)
                                    .foregroundStyle(Theme.pink)
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if reason == option {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.pink)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Why can't you do \(exercise.name)?")
                }

                if reason == .pain {
                    Section {
                        ForEach(BodyArea.allCases) { area in
                            Button {
                                if painAreas.contains(area) { painAreas.remove(area) } else { painAreas.insert(area) }
                                chosen = nil
                            } label: {
                                HStack {
                                    Text(area.title).foregroundStyle(.primary)
                                    Spacer()
                                    if painAreas.contains(area) {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.pink)
                                    }
                                }
                            }
                        }
                        Toggle("Keep protecting these areas in future workouts", isOn: $protectFromNowOn)
                            .tint(Theme.pink)
                            .disabled(painAreas.isEmpty)
                    } header: {
                        Text("Where does it hurt?")
                    } footer: {
                        Text("If pain is sharp or doesn't go away, please stop and see a professional.")
                    }
                }

                if reason != nil {
                    Section {
                        if suggestions.isEmpty {
                            Text(emptyHint)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(suggestions) { alternative in
                            Button { chosen = alternative } label: { row(alternative) }
                        }
                    } header: {
                        Text("Try instead")
                    }
                }

                if let chosen = chosen {
                    Section {
                        Picker("How long?", selection: $scope) {
                            ForEach(SwapScope.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        Button {
                            let areas = (reason == .pain && protectFromNowOn) ? Array(painAreas) : []
                            onSwap(chosen.exercise, scope, areas)
                            dismiss()
                        } label: {
                            Text("Swap to \(chosen.exercise.name)")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.pink)
                    } header: {
                        Text("Keep this swap")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onSkip()
                        dismiss()
                    } label: {
                        Text("Skip this exercise today")
                    }
                } footer: {
                    Text("Skipping doesn't change your plan. It just removes it from today's workout.")
                }
            }
            .navigationTitle("Swap exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ alternative: Alternative) -> some View {
        HStack(spacing: 12) {
            FigureThumb(exercise: alternative.exercise, animated: false)
                .frame(width: 64, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(alternative.exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(alternative.relation.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint(alternative.relation))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(tint(alternative.relation).opacity(0.15)))
                }
                Text(alternative.why)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: chosen?.id == alternative.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(chosen?.id == alternative.id ? Theme.pink : Color.primary.opacity(0.2))
        }
    }

    private func tint(_ relation: Relation) -> Color {
        switch relation {
        case .easier: return Theme.green
        case .similar: return Color.secondary
        case .harder: return Theme.amber
        }
    }

    private var emptyHint: String {
        switch reason {
        case .tooHard:
            return "There's no easier version of this for you. Try fewer reps with longer rests, or skip it today."
        case .tooEasy:
            return "No harder variation is available. For weighted lifts, just add weight: it goes up automatically when you hit the top of the rep range."
        case .pain:
            return "Nothing else avoids those areas for this movement. Skipping it today is the safest choice."
        case .noEquipment:
            return "No version with less equipment fits this movement. You can skip it today."
        default:
            return "No other exercise fits this spot with your current settings."
        }
    }
}
