import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    summary
                    stats
                    cards
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var today: Date { Date() }
    private var planned: Workout? { store.workout(on: today) }
    private var doneToday: [WorkoutSession] { store.sessions(on: today) }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(store.streak)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Theme.pink)
                            .frame(width: 11, height: 11)
                            .offset(x: 14, y: 6)
                    }
                Text("workout streak")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(today.formatted(.dateTime.month(.wide).day()) + ",")
                Text(today.formatted(.dateTime.year()))
            }
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    private var greetingName: String {
        let name = store.profile.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "" : ", \(name)"
    }

    private var summary: some View {
        Group {
            if !doneToday.isEmpty {
                Text("Nice work today\(greetingName). Add a quick session below if you still have energy.")
            } else if planned != nil {
                Text("Today's workout is scheduled. You have **1 workout** session.")
            } else if let next = store.nextWorkout() {
                Text("Rest day\(greetingName). Next up: **\(next.workout.title)** on \(next.date.formatted(.dateTime.weekday(.wide))).")
            } else {
                Text("Rest day\(greetingName). Recovery is part of the plan.")
            }
        }
        .font(.system(size: 17, weight: .medium))
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var stats: some View {
        let weight = store.profile.weightKg
        let logged = store.totals(on: today)
        let calories = logged.sessions > 0 ? logged.calories : (planned?.calories(weightKg: weight) ?? 0)
        let minutes = logged.sessions > 0 ? logged.minutes : (planned?.minutes ?? 0)
        let sets = logged.sessions > 0 ? logged.sets : (planned?.totalSets ?? 0)

        return HStack(spacing: 22) {
            StatPill(symbol: "flame.fill", value: "\(calories)", unit: "cal", tint: Theme.pink)
            StatPill(symbol: "timer", value: "\(minutes)", unit: "min", tint: Theme.green)
            StatPill(symbol: "checkmark.circle.fill", value: "\(sets)", unit: "sets", tint: Theme.amber)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: Cards

    private var cards: some View {
        let weight = store.profile.weightKg
        return VStack(spacing: 2) {
            if let workout = planned {
                NavigationLink(value: workout) {
                    WorkoutCard(
                        label: doneToday.isEmpty ? "Today's Workout" : "Today's Workout · Done",
                        workout: workout,
                        weightKg: weight
                    )
                }
            } else if let next = store.nextWorkout() {
                NavigationLink(value: next.workout) {
                    WorkoutCard(
                        label: "Up next · \(next.date.formatted(.dateTime.weekday(.wide)))",
                        workout: next.workout,
                        weightKg: weight
                    )
                }
            }

            ForEach(QuickKind.allCases) { kind in
                let workout = store.quick(kind)
                NavigationLink(value: workout) {
                    WorkoutCard(label: "Quick Workout", workout: workout, weightKg: weight)
                }
            }
        }
        .buttonStyle(.plain)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
    }
}
