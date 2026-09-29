import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @State private var draft: UserProfile = {
        var profile = UserProfile()
        profile.trainingWeekdays = [2, 4, 6]
        profile.sessionMinutes = 45
        return profile
    }()
    @State private var step = 0

    private let lastStep = 7

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0...lastStep, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Theme.pink : Color.primary.opacity(0.12))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            ScrollView {
                content
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: goalStep
        case 2: experienceStep
        case 3: checkStep
        case 4: scheduleStep
        case 5: equipmentStep
        case 6: bodyStep
        default: planStep
        }
    }

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    // 0 ------------------------------------------------------------------
    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.pink, Color(hex: 0xFF7A45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "flame.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 104, height: 104)
            .padding(.top, 24)

            header(
                "Momentum",
                "A free training plan built around you. It learns from every workout, and everything stays on this iPhone."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Your name", text: $draft.name)
                    .textContentType(.givenName)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
            }

            Label("No account, no sign-in, no tracking.", systemImage: "lock.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    // 1 ------------------------------------------------------------------
    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Your main goal", "This decides rep ranges, rest times, weekly volume and whether we add cardio.")
            ForEach(Goal.allCases) { goal in
                OptionCard(
                    symbol: goal.symbol,
                    title: goal.title,
                    subtitle: goal.summary,
                    selected: draft.goal == goal
                ) { draft.goal = goal }
            }
        }
    }

    // 2 ------------------------------------------------------------------
    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            header("Your experience", "Be honest. Starting a little easier is how progress lasts.")

            sectionLabel("How long have you trained consistently?")
            ForEach(TrainingHistory.allCases) { option in
                ChoiceRow(title: option.title, selected: draft.history == option) { draft.history = option }
            }

            sectionLabel("How often in the last three months?")
            ForEach(RecentFrequency.allCases) { option in
                ChoiceRow(title: option.title, selected: draft.frequency == option) { draft.frequency = option }
            }
        }
    }

    // 3 ------------------------------------------------------------------
    private func checkPicker(
        _ title: String,
        _ hint: String,
        selection: Binding<Int?>,
        options: [(label: String, value: Int)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(hint).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Picker(title, selection: selection) {
                    Text("Skip").tag(Int?.none)
                    ForEach(options, id: \.value) { option in
                        Text(option.label).tag(Int?.some(option.value))
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.pink)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var checkStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("A quick strength check", "Optional. It lets us start each movement at the right difficulty. Skip anything you'd rather not try.")

            checkPicker("Push-ups", "In a row, with good form", selection: $draft.check.pushups, options: [
                ("None yet", 0), ("1-4", 3), ("5-14", 10), ("15-24", 20), ("25+", 30)
            ])
            checkPicker("Bodyweight squats", "In a row, to parallel", selection: $draft.check.squats, options: [
                ("Under 15", 10), ("15-29", 20), ("30-44", 35), ("45+", 50)
            ])
            checkPicker("Plank hold", "On forearms, straight body", selection: $draft.check.plankSeconds, options: [
                ("Under 20 s", 15), ("20-44 s", 30), ("45-89 s", 60), ("90 s+", 100)
            ])
            checkPicker("Pull-ups", "Full reps, no swinging", selection: $draft.check.pullups, options: [
                ("None", 0), ("1-2", 1), ("3-7", 5), ("8+", 10)
            ])

            Label("Nothing here is judged. If a movement turns out too easy or hard, the app moves you up or down on its own.", systemImage: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // 4 ------------------------------------------------------------------
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    private func weekdayName(_ weekday: Int) -> String {
        Calendar.current.shortWeekdaySymbols[weekday - 1]
    }

    private func toggleWeekday(_ weekday: Int) {
        var days = draft.trainingWeekdays
        if let index = days.firstIndex(of: weekday) {
            if days.count > 1 { days.remove(at: index) }
        } else if days.count < 6 {
            days.append(weekday)
        }
        draft.trainingWeekdays = days
    }

    private var scheduleSummary: String {
        var preview = draft
        preview.level = Assessment.place(draft).level
        let titles = PlanGenerator.split(for: preview).map { $0.title }
        return titles.joined(separator: " · ")
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header("Your schedule", "Pick the days you can really train. We build the split around them.")

            HStack(spacing: 6) {
                ForEach(Self.weekdayOrder, id: \.self) { weekday in
                    let on = draft.trainingWeekdays.contains(weekday)
                    Button { toggleWeekday(weekday) } label: {
                        Text(weekdayName(weekday))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Theme.pink : Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            Text("**\(draft.trainingWeekdays.count)** days a week: \(scheduleSummary)")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            sectionLabel("Time you have per session")
            Picker("Session length", selection: $draft.sessionMinutes) {
                ForEach([20, 30, 45, 60, 90], id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            Text("This is a ceiling. If your level needs less volume to make progress, sessions will be shorter and we'll say so.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    // 5 ------------------------------------------------------------------
    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Your equipment", "We only pick exercises you can actually do.")
            ForEach(Equipment.allCases) { equipment in
                OptionCard(
                    symbol: equipment.symbol,
                    title: equipment.title,
                    subtitle: equipment.summary,
                    selected: draft.equipment == equipment
                ) { draft.equipment = equipment }
            }

            if draft.equipment == .dumbbells {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Adjustable or plenty of weights", isOn: Binding(
                        get: { draft.maxDumbbellKg == 0 },
                        set: { draft.maxDumbbellKg = $0 ? 0 : 20 }
                    ))
                    .tint(Theme.pink)
                    if draft.maxDumbbellKg > 0 {
                        Stepper(value: dumbbellBinding, in: dumbbellRange, step: 1) {
                            Text("Heaviest dumbbell **\(Int(dumbbellBinding.wrappedValue)) \(draft.units.weightLabel)**")
                        }
                        Text("When you outgrow it, we add reps and harder variations instead of asking for more weight.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            }
        }
    }

    // 6 ------------------------------------------------------------------
    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header("About you", "Used to pick safe starting weights and estimate calories. You can change it any time.")

            Picker("Sex", selection: $draft.sex) {
                ForEach(Sex.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Units", selection: $draft.units) {
                ForEach(UnitSystem.allCases) { units in
                    Text(units == .metric ? "Metric" : "Imperial").tag(units)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: weightBinding, in: weightRange, step: 1) {
                Text("Weight **\(Int(weightBinding.wrappedValue)) \(draft.units.weightLabel)**")
            }
            Stepper(value: heightBinding, in: heightRange, step: 1) {
                Text("Height **\(Int(heightBinding.wrappedValue)) \(draft.units.heightLabel)**")
            }
            Stepper(value: $draft.age, in: 14...90) {
                Text("Age **\(draft.age)**")
            }

            sectionLabel("Anything we should protect?")
            Text("We'll never pick exercises that load these areas.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(BodyArea.allCases) { area in
                    let on = draft.limitations.contains(area)
                    Button {
                        if on { draft.limitations.removeAll { $0 == area } } else { draft.limitations.append(area) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            Text(area.title).font(.system(size: 15, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(on ? Theme.pink : Color.primary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Toggle("Low impact only (no jumping)", isOn: $draft.lowImpactOnly)
                .tint(Theme.pink)
                .font(.system(size: 15))

            Label("Momentum is not medical advice. If something hurts, stop and see a professional.", systemImage: "cross.case")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // 7 ------------------------------------------------------------------
    private var previewProfile: UserProfile {
        var profile = draft
        let placement = Assessment.place(draft)
        profile.level = placement.level
        profile.rungs = placement.rungs
        profile.startDate = Date()
        profile.blockStart = TrainingCalendar.weekStart(of: Date())
        return profile
    }

    private var planStep: some View {
        let profile = previewProfile
        let placement = Assessment.place(draft)
        let week = PlanGenerator.week(containing: Date(), profile: profile, history: [])
        let planned = PlanGenerator.plannedSets(in: week)
        let targets = VolumePlanner.weeklyTargets(for: profile)

        return VStack(alignment: .leading, spacing: 16) {
            header(draft.name.isEmpty ? "Your plan" : "\(draft.name), here's your plan", "Built from your answers. It changes as you train.")

            planCard("Where you start", symbol: "figure.walk") {
                ForEach(placement.notes, id: \.self) { note in
                    Text("• \(note)").font(.system(size: 14))
                }
            }

            planCard("Your week", symbol: "calendar") {
                ForEach(Array(week.enumerated()), id: \.offset) { pair in
                    HStack {
                        Text(pair.element.date.formatted(.dateTime.weekday(.wide)))
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text("\(pair.element.workout.title) · ~\(pair.element.workout.minutes) min")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            planCard("Weekly sets per muscle", symbol: "chart.bar.fill") {
                ForEach(VolumePlanner.muscles, id: \.self) { muscle in
                    if let target = targets[muscle] {
                        HStack {
                            Text(muscle.title).font(.system(size: 14, weight: .medium))
                            Spacer()
                            Text("\(planned[muscle] ?? 0) planned · goal \(target.low)-\(target.high)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            planCard("How it adapts", symbol: "wand.and.stars") {
                Text("• Weights and reps move up when you hit the top of the range, and hold or drop when you don't.")
                Text("• Bodyweight moves step up to harder versions as you master them.")
                Text("• A lighter deload week comes every \(Periodization.blockLength(for: profile.level)) weeks, or sooner if you're worn out.")
                Text("• After time off, weights come back gently.")
                Text("• Swap any exercise you can't do, and we'll suggest the right alternative.")
            }

            Toggle(isOn: healthBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Apple Health")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Save workouts and weight to Health and show your steps.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.pink)
            .disabled(!HealthService.isAvailable)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    private func planCard<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.pink)
            content()
                .font(.system(size: 14))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            Spacer()
            Button(step == lastStep ? "Start training" : "Continue") {
                if step == lastStep {
                    store.completeOnboarding(draft)
                } else {
                    step += 1
                }
            }
            .buttonStyle(PillButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    // MARK: Bindings

    private var weightRange: ClosedRange<Double> {
        draft.units == .metric ? 30...250 : 66...550
    }

    private var heightRange: ClosedRange<Double> {
        draft.units == .metric ? 120...230 : 48...90
    }

    private var dumbbellRange: ClosedRange<Double> {
        draft.units == .metric ? 2...60 : 5...130
    }

    private var healthBinding: Binding<Bool> {
        Binding(
            get: { draft.healthSync },
            set: { enabled in
                if enabled {
                    Task { @MainActor in draft.healthSync = await health.requestAccess() }
                } else {
                    draft.healthSync = false
                }
            }
        )
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { draft.units.displayWeight(draft.weightKg).rounded() },
            set: { draft.weightKg = draft.units.kg(fromDisplay: $0) }
        )
    }

    private var heightBinding: Binding<Double> {
        Binding(
            get: { draft.units.displayHeight(draft.heightCm).rounded() },
            set: { draft.heightCm = draft.units.cm(fromDisplay: $0) }
        )
    }

    private var dumbbellBinding: Binding<Double> {
        Binding(
            get: { draft.units.displayWeight(draft.maxDumbbellKg).rounded() },
            set: { draft.maxDumbbellKg = draft.units.kg(fromDisplay: $0) }
        )
    }
}

/// Compact single-choice row.
struct ChoiceRow: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Theme.pink : Color.primary.opacity(0.2))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Theme.pink : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct OptionCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconBadge(symbol: symbol, tint: selected ? Theme.pink : Color.gray.opacity(0.5), size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Theme.pink : Color.primary.opacity(0.2))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Theme.pink : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
