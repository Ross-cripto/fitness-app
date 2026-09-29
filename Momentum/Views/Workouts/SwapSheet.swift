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
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                if reason == option {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.pink)
                                }
                            }
                        }
                    }
                } header: {
                    Text(L("Why can't you do {0}?", exercise.name))
                }

                if reason == .pain {
                    Section {
                        ForEach(BodyArea.allCases) { area in
                            Button {
                                if painAreas.contains(area) { painAreas.remove(area) } else { painAreas.insert(area) }
                                chosen = nil
                            } label: {
                                HStack {
                                    Text(area.title).foregroundStyle(Color.primary)
                                    Spacer()
                                    if painAreas.contains(area) {
                                        Image(systemName: "checkmark").foregroundStyle(Theme.pink)
                                    }
                                }
                            }
                        }
                        Toggle(L("Keep protecting these areas in future workouts"), isOn: $protectFromNowOn)
                            .tint(Theme.pink)
                            .disabled(painAreas.isEmpty)
                    } header: {
                        Text(L("Where does it hurt?"))
                    } footer: {
                        Text(L("If pain is sharp or doesn't go away, please stop and see a professional."))
                    }
                }

                if reason != nil {
                    Section {
                        if suggestions.isEmpty {
                            Text(emptyHint)
                                .scaledFont(size: 14)
                                .foregroundStyle(Color.secondary)
                        }
                        ForEach(suggestions) { alternative in
                            Button { chosen = alternative } label: { row(alternative) }
                        }
                    } header: {
                        Text(L("Try instead"))
                    }
                }

                if let chosen = chosen {
                    Section {
                        Picker(L("How long?"), selection: $scope) {
                            ForEach(SwapScope.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                        Button {
                            let areas = (reason == .pain && protectFromNowOn) ? Array(painAreas) : []
                            onSwap(chosen.exercise, scope, areas)
                            dismiss()
                        } label: {
                            Text(L("Swap to {0}", chosen.exercise.name))
                                .scaledFont(size: 16, weight: .semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.pink)
                    } header: {
                        Text(L("Keep this swap"))
                    }
                }

                if workout.exercises.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            onSkip()
                            dismiss()
                        } label: {
                            Text(L("Skip this exercise today"))
                        }
                    } footer: {
                        Text(L("Skipping doesn't change your plan. It just removes it from today's workout."))
                    }
                }
            }
            .navigationTitle(L("Swap exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Cancel")) { dismiss() }
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
                        .scaledFont(size: 16, weight: .semibold)
                        .foregroundStyle(Color.primary)
                    Text(alternative.relation.title)
                        .scaledFont(size: 11, weight: .bold)
                        .foregroundStyle(relationTint(alternative.relation))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(relationTint(alternative.relation).opacity(0.15)))
                }
                Text(alternative.why)
                    .scaledFont(size: 13)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: chosen?.id == alternative.id ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(chosen?.id == alternative.id ? Theme.pink : Color.primary.opacity(0.2))
        }
    }

    private func relationTint(_ relation: Relation) -> Color {
        switch relation {
        case .easier: return Theme.green
        case .similar: return Color.secondary
        case .harder: return Theme.amber
        }
    }

    private var emptyHint: String {
        switch reason {
        case .tooHard:
            return L("There's no easier version of this for you. Try fewer reps with longer rests, or skip it today.")
        case .tooEasy:
            return L("No harder variation is available. For weighted lifts, just add weight: it goes up automatically when you hit the top of the rep range.")
        case .pain:
            return L("Nothing else avoids those areas for this movement. Skipping it today is the safest choice.")
        case .noEquipment:
            return L("No version with less equipment fits this movement. You can skip it today.")
        default:
            return L("No other exercise fits this spot with your current settings.")
        }
    }
}
