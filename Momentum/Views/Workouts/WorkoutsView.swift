import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    summary
                    stats
                    WeekStrip()
                    cards
                }
            }
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .task(id: scenePhase) {
                if store.profile.healthSync && scenePhase == .active { await health.refreshToday() }
            }
        }
    }

    private var today: Date { Date() }
    private var planned: Workout? { store.workout(on: today) }
    private var doneToday: [WorkoutSession] { store.sessions(on: today) }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "\(store.streak)")
                    .scaledFont(size: 64, weight: .heavy, design: .rounded)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Theme.pink)
                            .frame(width: 11, height: 11)
                            .offset(x: 14, y: 6)
                    }
                Text(L("workout streak"))
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(Loc.date(today, "MMMMd") + ",")
                Text(Loc.date(today, "y"))
            }
            .scaledFont(size: 20, weight: .regular)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    private var trimmedName: String {
        store.profile.name.trimmingCharacters(in: .whitespaces)
    }

    private var summary: some View {
        Group {
            if !doneToday.isEmpty {
                if trimmedName.isEmpty {
                    Text(L("Nice work today. Add a quick session below if you still have energy."))
                } else {
                    Text(L("Nice work today, {0}. Add a quick session below if you still have energy.", trimmedName))
                }
            } else if planned != nil {
                LText("Today's workout is scheduled. You have **1 workout** session.")
            } else if let next = store.nextWorkout() {
                if trimmedName.isEmpty {
                    LText("Rest day. Next up: **{0}** on {1}.", next.workout.title, Loc.date(next.date, "EEEE"))
                } else {
                    LText("Rest day, {0}. Next up: **{1}** on {2}.", trimmedName, next.workout.title, Loc.date(next.date, "EEEE"))
                }
            } else if trimmedName.isEmpty {
                Text(L("Rest day. Recovery is part of the plan."))
            } else {
                Text(L("Rest day, {0}. Recovery is part of the plan.", trimmedName))
            }
        }
        .scaledFont(size: 17, weight: .medium)
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
            StatPill(symbol: "flame.fill", value: "\(calories)", unit: L("cal"), tint: Theme.pink)
            StatPill(symbol: "timer", value: "\(minutes)", unit: L("min"), tint: Theme.green)
            if store.profile.healthSync && health.steps > 0 {
                StatPill(symbol: "figure.walk", value: "\(health.steps)", unit: L("steps"), tint: Theme.amber)
            } else {
                StatPill(symbol: "checkmark.circle.fill", value: "\(sets)", unit: L("sets"), tint: Theme.amber)
            }
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
                        label: doneToday.isEmpty ? L("Today's Workout") : L("Today's Workout · Done"),
                        workout: workout,
                        weightKg: weight
                    )
                }
                .accessibilityIdentifier("mainWorkoutCard")
            } else if let next = store.nextWorkout() {
                NavigationLink(value: next.workout) {
                    WorkoutCard(
                        label: L("Up next · {0}", Loc.date(next.date, "EEEE")),
                        workout: next.workout,
                        weightKg: weight
                    )
                }
                .accessibilityIdentifier("mainWorkoutCard")
            }

            ForEach(QuickKind.allCases) { kind in
                let workout = store.quick(kind)
                NavigationLink(value: workout) {
                    WorkoutCard(label: L("Quick Workout"), workout: workout, weightKg: weight)
                }
            }
        }
        .buttonStyle(.plain)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
    }
}
