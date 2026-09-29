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
                .scaledFont(size: 32, weight: .bold)
            Text(subtitle)
                .scaledFont(size: 16)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .scaledFont(size: 14, weight: .semibold)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    // 0 ------------------------------------------------------------------
    private var languagePicker: some View {
        HStack(spacing: 8) {
            ForEach(AppLanguage.allCases) { language in
                let current = store.language == language
                Button { store.profile.language = language } label: {
                    Text(language.nativeName)
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundStyle(current ? Color.white : Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(current ? Theme.pink : Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(current ? .isSelected : [])
            }
            Spacer()
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            languagePicker

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.pink, Color(hex: 0xFF7A45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "flame.fill")
                    .scaledFont(size: 54, weight: .bold)
                    .foregroundStyle(.white)
            }
            .frame(width: 104, height: 104)
            .padding(.top, 24)

            header(
                L("Momentum"),
                L("A free training plan built around you. It learns from every workout, and everything stays on this iPhone.")
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(L("What should we call you?"))
                    .scaledFont(size: 14, weight: .semibold)
                    .foregroundStyle(.secondary)
                TextField(L("Your name"), text: $draft.name)
                    .textContentType(.givenName)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
            }

            Label(L("No account, no sign-in, no tracking."), systemImage: "lock.fill")
                .scaledFont(size: 13)
                .foregroundStyle(.secondary)
        }
    }

    // 1 ------------------------------------------------------------------
    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(L("Your main goal"), L("This decides rep ranges, rest times, weekly volume and whether we add cardio."))
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
            header(L("Your experience"), L("Be honest. Starting a little easier is how progress lasts."))

            sectionLabel(L("How long have you trained consistently?"))
            ForEach(TrainingHistory.allCases) { option in
                ChoiceRow(title: option.title, selected: draft.history == option) { draft.history = option }
            }

            sectionLabel(L("How often in the last three months?"))
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
                    Text(title).scaledFont(size: 16, weight: .semibold)
                    Text(hint).scaledFont(size: 12).foregroundStyle(.secondary)
                }
                Spacer()
                Picker(title, selection: selection) {
                    Text(L("Skip")).tag(Int?.none)
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
            header(L("A quick strength check"), L("Optional. It lets us start each movement at the right difficulty. Skip anything you'd rather not try."))

            checkPicker(L("Push-ups"), L("In a row, with good form"), selection: $draft.check.pushups, options: [
                (L("None yet"), 0), ("1-4", 3), ("5-14", 10), ("15-24", 20), ("25+", 30)
            ])
            checkPicker(L("Bodyweight squats"), L("In a row, to parallel"), selection: $draft.check.squats, options: [
                (L("Under 15"), 10), ("15-29", 20), ("30-44", 35), ("45+", 50)
            ])
            checkPicker(L("Plank hold"), L("On forearms, straight body"), selection: $draft.check.plankSeconds, options: [
                (L("Under 20 s"), 15), (L("20-44 s"), 30), (L("45-89 s"), 60), (L("90 s+"), 100)
            ])
            checkPicker(L("Pull-ups"), L("Full reps, no swinging"), selection: $draft.check.pullups, options: [
                (L("None"), 0), ("1-2", 1), ("3-7", 5), ("8+", 10)
            ])

            Label(L("Nothing here is judged. If a movement turns out too easy or hard, the app moves you up or down on its own."), systemImage: "info.circle")
                .scaledFont(size: 13)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    // 4 ------------------------------------------------------------------
    private static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]

    private func weekdayName(_ weekday: Int) -> String {
        Loc.calendar.shortWeekdaySymbols[weekday - 1]
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
            header(L("Your schedule"), L("Pick the days you can really train. We build the split around them."))

            HStack(spacing: 6) {
                ForEach(Self.weekdayOrder, id: \.self) { weekday in
                    let on = draft.trainingWeekdays.contains(weekday)
                    Button { toggleWeekday(weekday) } label: {
                        Text(weekdayName(weekday))
                            .scaledFont(size: 13, weight: .semibold)
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Theme.pink : Color.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            Group {
                if draft.trainingWeekdays.count == 1 {
                    LText("**{0}** day a week: {1}", draft.trainingWeekdays.count, scheduleSummary)
                } else {
                    LText("**{0}** days a week: {1}", draft.trainingWeekdays.count, scheduleSummary)
                }
            }
            .scaledFont(size: 14)
            .foregroundStyle(.secondary)

            sectionLabel(L("Time you have per session"))
            Picker(L("Session length"), selection: $draft.sessionMinutes) {
                ForEach([20, 30, 45, 60, 90], id: \.self) { minutes in
                    Text(L("{0} min", minutes)).tag(minutes)
                }
            }
            .pickerStyle(.segmented)
            Text(L("This is a ceiling. If your level needs less volume to make progress, sessions will be shorter and we'll say so."))
                .scaledFont(size: 12)
                .foregroundStyle(.secondary)
        }
    }

    // 5 ------------------------------------------------------------------
    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header(L("Your equipment"), L("We only pick exercises you can actually do."))
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
                    Toggle(L("Adjustable or plenty of weights"), isOn: Binding(
                        get: { draft.maxDumbbellKg == 0 },
                        set: { draft.maxDumbbellKg = $0 ? 0 : 20 }
                    ))
                    .tint(Theme.pink)
                    if draft.maxDumbbellKg > 0 {
                        Stepper(value: dumbbellBinding, in: dumbbellRange, step: 1) {
                            LText("Heaviest dumbbell **{0} {1}**", Int(dumbbellBinding.wrappedValue), draft.units.weightLabel)
                        }
                        Text(L("When you outgrow it, we add reps and harder variations instead of asking for more weight."))
                            .scaledFont(size: 12)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            }

            if draft.equipment != .fullGym {
                Toggle(L("I have a pull-up bar"), isOn: $draft.hasPullUpBar)
                    .tint(Theme.pink)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            }
        }
    }

    // 6 ------------------------------------------------------------------
    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(L("About you"), L("Used to pick safe starting weights and estimate calories. You can change it any time."))

            Picker(L("Sex"), selection: $draft.sex) {
                ForEach(Sex.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker(L("Units"), selection: $draft.units) {
                ForEach(UnitSystem.allCases) { units in
                    Text(units == .metric ? L("Metric") : L("Imperial")).tag(units)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 14) {
                Stepper(value: weightBinding, in: weightRange, step: 1) {
                    LText("Weight **{0} {1}**", Int(weightBinding.wrappedValue), draft.units.weightLabel)
                }
                Stepper(value: heightBinding, in: heightRange, step: 1) {
                    LText("Height **{0} {1}**", Int(heightBinding.wrappedValue), draft.units.heightLabel)
                }
                Stepper(value: $draft.age, in: 14...90) {
                    LText("Age **{0}**", draft.age)
                }
            }

            sectionLabel(L("Anything we should protect?"))
            Text(L("We'll never pick exercises that load these areas."))
                .scaledFont(size: 12)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(BodyArea.allCases) { area in
                    let on = draft.limitations.contains(area)
                    Button {
                        if on { draft.limitations.removeAll { $0 == area } } else { draft.limitations.append(area) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            Text(area.title).scaledFont(size: 15, weight: .medium)
                            Spacer()
                        }
                        .foregroundStyle(on ? Theme.pink : Color.primary)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Toggle(L("Low impact only (no jumping)"), isOn: $draft.lowImpactOnly)
                .tint(Theme.pink)
                .scaledFont(size: 15)

            Label(L("Momentum is not medical advice. If something hurts, stop and see a professional."), systemImage: "cross.case")
                .scaledFont(size: 12)
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
            header(draft.name.isEmpty ? L("Your plan") : L("{0}, here's your plan", draft.name), L("Built from your answers. It changes as you train."))

            planCard(L("Where you start"), symbol: "figure.walk") {
                ForEach(placement.notes, id: \.self) { note in
                    Text(L("• {0}", note)).scaledFont(size: 14)
                }
            }

            planCard(L("Your week"), symbol: "calendar") {
                ForEach(Array(week.enumerated()), id: \.offset) { pair in
                    HStack {
                        Text(Loc.date(pair.element.date, "EEEE"))
                            .scaledFont(size: 14, weight: .semibold)
                        Spacer()
                        Text(L("{0} · ~{1} min", pair.element.workout.title, pair.element.workout.minutes))
                            .scaledFont(size: 14)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            planCard(L("Weekly sets per muscle"), symbol: "chart.bar.fill") {
                ForEach(VolumePlanner.muscles, id: \.self) { muscle in
                    if let target = targets[muscle] {
                        HStack {
                            Text(muscle.title).scaledFont(size: 14, weight: .medium)
                            Spacer()
                            Text(L("{0} planned · goal {1}-{2}", planned[muscle] ?? 0, target.low, target.high))
                                .scaledFont(size: 13)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            planCard(L("How it adapts"), symbol: "wand.and.stars") {
                Text(L("• Weights and reps move up when you hit the top of the range, and hold or drop when you don't."))
                Text(L("• Bodyweight moves step up to harder versions as you master them."))
                Text(L("• A lighter deload week comes every {0} weeks, or sooner if you're worn out.", Periodization.blockLength(for: profile.level)))
                Text(L("• After time off, weights come back gently."))
                Text(L("• Swap any exercise you can't do, and we'll suggest the right alternative."))
            }

            Toggle(isOn: healthBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Connect Apple Health"))
                        .scaledFont(size: 16, weight: .semibold)
                    Text(L("Save workouts and weight to Health and show your steps."))
                        .scaledFont(size: 13)
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
                .scaledFont(size: 15, weight: .semibold)
                .foregroundStyle(Theme.pink)
            content()
                .scaledFont(size: 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button(L("Back")) { step -= 1 }
                    .scaledFont(size: 16, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
            }
            Spacer()
            Button(step == lastStep ? L("Start training") : L("Continue")) {
                if step == lastStep {
                    // The language picked on the first step lives on the store, not the draft.
                    draft.language = store.profile.language
                    store.completeOnboarding(draft)
                } else {
                    step += 1
                }
            }
            .buttonStyle(PillButtonStyle())
            .accessibilityIdentifier("onboardingNext")
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
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 20)
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
                        .scaledFont(size: 17, weight: .semibold)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .scaledFont(size: 13)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .scaledFont(size: 22)
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
