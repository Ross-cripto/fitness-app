import SwiftUI
import Charts

struct ProgressTabView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService

    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var showSettings = false
    @State private var showWeightSheet = false

    private var calendar: Calendar { Loc.calendar }
    private var units: UnitSystem { store.profile.units }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    dateStrip
                    calorieCard
                    durationCard
                    volumeCard
                    weightCard
                    healthCard
                    recordsCard
                    daySessions
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if store.profile.healthSync { await health.refreshToday() }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store).environmentObject(health)
            }
            .sheet(isPresented: $showWeightSheet) {
                LogWeightSheet().environmentObject(store).environmentObject(health)
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(L("Your Progress"))
                .font(.system(size: 30, weight: .bold))
            Spacer()
            Button { showSettings = true } label: {
                Text(initial)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient(colors: [Theme.pink, Color(hex: 0xFF7A45)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            .accessibilityLabel(L("Settings"))
        }
    }

    private var initial: String {
        let name = store.profile.name.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "M" : String(name.prefix(1)).uppercased()
    }

    // MARK: Date strip

    private var days: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<14).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        dateChip(day)
                    }
                }
            }
            .onAppear {
                if let last = days.last { proxy.scrollTo(last, anchor: .trailing) }
            }
        }
    }

    private func dateChip(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let hasWorkout = !store.sessions(on: day).isEmpty
        let title: String = {
            guard isSelected else { return Loc.date(day, "d") }
            let label = calendar.isDateInToday(day) ? L("Today") : Loc.date(day, "EEE")
            return L("{0}, {1}", label, Loc.date(day, "MMMd"))
        }()

        return Button { selected = day } label: {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                Circle()
                    .fill(hasWorkout ? (isSelected ? Color.white : Theme.pink) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .padding(.horizontal, isSelected ? 14 : 9)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isSelected ? Theme.blue : Color.clear))
        }
        .buttonStyle(.plain)
        .id(day)
    }

    // MARK: Cards

    private var weekTotals: Totals { store.weekTotals(containing: selected) }
    private var goal: (calories: Int, minutes: Int) { store.weeklyGoal(containing: selected) }

    private func ratio(_ value: Int, _ target: Int) -> Double {
        target > 0 ? Double(value) / Double(target) : 0
    }

    private func percent(_ ratio: Double) -> Int { Int((ratio * 100).rounded()) }

    private func encouragement(_ ratio: Double, calories: Bool) -> String {
        switch ratio {
        case 1...: return L("Goal reached. Outstanding work, keep the momentum going.")
        case 0.6...:
            return calories
                ? L("Well done! You're well on your way with your calorie burn this week.")
                : L("Well done! You're well on your way with your training time this week.")
        case 0.01...: return L("Good start. Every session moves the needle.")
        default: return L("Your week is wide open. Let's get the first workout in.")
        }
    }

    private var calorieCard: some View {
        let value = weekTotals.calories
        let target = goal.calories
        let r = ratio(value, target)
        return VStack(alignment: .leading, spacing: 12) {
            IconBadge(symbol: "flame.fill", tint: Theme.pink, size: 42)
            Text(L("Calorie"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.pink)
            Text(encouragement(r, calories: true))
                .font(.system(size: 14))
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(value))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(L("/{0} Cal.", target))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.pink)
                Spacer()
                Text(L("{0}% Completed", percent(r)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            ProgressBar(value: r, tint: Theme.pink)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var durationCard: some View {
        let value = weekTotals.minutes
        let target = goal.minutes
        let r = ratio(value, target)
        let bars = store.dailyMinutes(endingAt: selected, days: 28)
        return VStack(alignment: .leading, spacing: 12) {
            IconBadge(symbol: "timer", tint: Theme.green, size: 42)
            Text(L("Duration"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.green)
            Text(encouragement(r, calories: false))
                .font(.system(size: 14))
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(String(value))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(L("/{0} mins.", target))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.green)
                Spacer()
                Text(L("{0}% Completed", percent(r)))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Chart(bars) { bar in
                BarMark(
                    x: .value(L("Day"), bar.date, unit: .day),
                    y: .value(L("Minutes"), bar.minutes),
                    width: .fixed(5)
                )
                .foregroundStyle(Theme.green.opacity(bar.minutes > 0 ? 1 : 0.25))
                .cornerRadius(2)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 48)
        }
        .card()
        .accessibilityElement(children: .combine)
    }

    private var volumeCard: some View {
        let rows = store.volumeThisWeek(containing: selected)
        let phase = Periodization.phase(on: selected, profile: store.profile, history: store.sessions)
        let purple = Color(hex: 0x7A5CFF)
        return VStack(alignment: .leading, spacing: 12) {
            IconBadge(symbol: "chart.bar.fill", tint: purple, size: 42)
            Text(L("Weekly volume"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(purple)
            Text(L("Hard sets per muscle this week against the range that builds progress at your level."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(row.muscle.title).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Text(L("{0} / {1}-{2}", row.done, row.target.low, row.target.high))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(row.done >= row.target.low ? Theme.green : Color.secondary)
                    }
                    ProgressBar(value: Double(row.done) / Double(max(1, row.target.high)), tint: row.done >= row.target.low ? Theme.green : purple)
                }
            }
            Text(L("{0} · {1}", phase.label, Lp(phase.repsInReserve, one: "Stop {0} rep short of failure", other: "Stop {0} reps short of failure")))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var weightCard: some View {
        let entries = store.weights
        let latest = entries.last?.kg ?? store.profile.weightKg
        let change = entries.count > 1 ? latest - (entries.first?.kg ?? latest) : 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                IconBadge(symbol: "scalemass.fill", tint: Theme.blue, size: 42)
                Spacer()
                Button(L("Log weight")) { showWeightSheet = true }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.blue)
            }
            Text(L("Body weight"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.blue)
            HStack(alignment: .firstTextBaseline) {
                Text(units.formatWeight(latest))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Spacer()
                if change != 0 {
                    let sign = change > 0 ? "+" : "-"
                    Text(L("{0} since start", "\(sign)\(units.formatWeight(abs(change)))"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            if entries.count > 1 {
                Chart(entries) { entry in
                    LineMark(
                        x: .value(L("Date"), entry.date),
                        y: .value(L("Weight"), units.displayWeight(entry.kg))
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.blue)
                    PointMark(
                        x: .value(L("Date"), entry.date),
                        y: .value(L("Weight"), units.displayWeight(entry.kg))
                    )
                    .foregroundStyle(Theme.blue)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 100)
            } else {
                Text(L("Log your weight regularly to see the trend here."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            IconBadge(symbol: "heart.fill", tint: Color(hex: 0xFF3B5C), size: 42)
            Text(L("Apple Health"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF3B5C))
            if store.profile.healthSync {
                HStack(spacing: 24) {
                    StatPill(symbol: "figure.walk", value: "\(health.steps)", unit: L("steps today"), tint: Theme.amber, large: false)
                    StatPill(symbol: "flame.fill", value: "\(health.activeCalories)", unit: L("active cal"), tint: Theme.pink, large: false)
                }
                Text(L("Workouts and body weight you log here are saved to Apple Health."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text(L("Save your workouts and weight to Apple Health, and see today's steps and active energy, including Apple Watch data."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button(L("Connect Apple Health")) {
                    Task { @MainActor in
                        if await health.requestAccess() {
                            store.profile.healthSync = true
                            await health.refreshToday()
                        }
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(hex: 0xFF3B5C))
                .disabled(!HealthService.isAvailable)
            }
        }
        .card()
    }

    private var recordsCard: some View {
        let records = store.personalRecords()
        return VStack(alignment: .leading, spacing: 12) {
            IconBadge(symbol: "trophy.fill", tint: Theme.amber, size: 42)
            Text(L("Personal records"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.amber)
            if records.isEmpty {
                Text(L("Your heaviest lifts will show up here after your first weighted workout."))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    HStack {
                        Text(record.exercise.name)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(units.formatWeight(record.kg))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            if let estimate = store.bestEstimatedOneRepMax(for: record.exercise.id) {
                                Text(L("est. 1RM {0}", units.formatWeight(estimate)))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .card()
    }

    private var daySessions: some View {
        let list = store.sessions(on: selected)
        return VStack(alignment: .leading, spacing: 10) {
            Text(calendar.isDateInToday(selected) ? L("Today's sessions") : L("Sessions on {0}", Loc.date(selected, "MMMd")))
                .font(.system(size: 17, weight: .semibold))
            if list.isEmpty {
                Text(L("No workouts logged on this day."))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title).font(.system(size: 15, weight: .semibold))
                            Text(Loc.date(session.date, "jm"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(L("{0} min · {1} cal", session.durationSeconds / 60, session.calories))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    .contextMenu {
                        Button(L("Delete"), role: .destructive) { store.delete(session) }
                    }
                }
            }
        }
    }
}

struct LogWeightSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @Environment(\.dismiss) private var dismiss
    @State private var display: Double = 0
    @State private var importMessage: String?

    var body: some View {
        let units = store.profile.units
        VStack(alignment: .leading, spacing: 20) {
            Text(L("Log body weight"))
                .font(.system(size: 24, weight: .bold))
            Stepper(value: $display, in: 20...1100, step: units.weightStep) {
                LText("**{0} {1}**", Loc.number(display), units.weightLabel)
                    .font(.system(size: 20))
            }
            Button(L("Save")) {
                let kg = units.kg(fromDisplay: display)
                store.addWeight(kg: kg)
                if store.profile.healthSync {
                    Task { @MainActor in await health.saveBodyWeight(kg: kg) }
                }
                dismiss()
            }
            .buttonStyle(PillButtonStyle(tint: Theme.blue))
            if store.profile.healthSync {
                Button {
                    Task { @MainActor in
                        if let latest = await health.latestBodyWeight() {
                            store.addWeight(kg: latest.kg, on: latest.date)
                            dismiss()
                        } else {
                            importMessage = L("No weight found in Apple Health.")
                        }
                    }
                } label: {
                    Label(L("Use latest weight from Apple Health"), systemImage: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0xFF3B5C))
                if let message = importMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(24)
        .onAppear { display = units.displayWeight(store.profile.weightKg).rounded() }
    }
}
