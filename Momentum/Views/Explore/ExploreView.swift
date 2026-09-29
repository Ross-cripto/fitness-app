import SwiftUI

struct ExploreView: View {
    @State private var query = ""
    @State private var muscle: MuscleGroup?
    @State private var selected: Exercise?

    private var results: [Exercise] {
        ExerciseLibrary.all
            .filter { muscle == nil || $0.muscle == muscle }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", isOn: muscle == nil) { muscle = nil }
                            ForEach(MuscleGroup.allCases) { group in
                                chip(group.title, isOn: muscle == group) { muscle = group }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                Section("\(results.count) exercises") {
                    ForEach(results) { exercise in
                        Button { selected = exercise } label: {
                            HStack(spacing: 12) {
                                FigureThumb(exercise: exercise)
                                    .frame(width: 56, height: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(exercise.muscle.title) · \(exercise.equipment.title) · \(exercise.level.title)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Explore")
            .searchable(text: $query, prompt: "Search exercises")
            .sheet(item: $selected) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(isOn ? Theme.pink : Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FigureCard(exercise: exercise)
                        .frame(height: 240)

                    Text(exercise.name)
                        .font(.system(size: 28, weight: .bold))

                    HStack(spacing: 8) {
                        pill(exercise.muscle.title)
                        pill(exercise.equipment.title)
                        pill(exercise.level.title)
                        if exercise.kind == .timed { pill("Timed") }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to")
                            .font(.system(size: 17, weight: .semibold))
                        ForEach(Array(exercise.steps.enumerated()), id: \.offset) { pair in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(pair.offset + 1)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Theme.pink))
                                Text(pair.element)
                                    .font(.system(size: 15))
                            }
                        }
                    }

                    Link(destination: exercise.videoURL) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Watch a video on YouTube")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("Proper-form tutorials for \(exercise.name)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    }

                    if let best = store.bestSet(for: exercise.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your best")
                                .font(.system(size: 17, weight: .semibold))
                            Text(bestText(best))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.pink)
                        }
                        .card()
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    private func bestText(_ set: SetLog) -> String {
        let units = store.profile.units
        if exercise.kind == .timed { return "\(set.seconds) sec hold" }
        if set.weightKg > 0 { return "\(units.formatWeight(set.weightKg)) × \(set.reps)" }
        return "\(set.reps) reps"
    }
}
