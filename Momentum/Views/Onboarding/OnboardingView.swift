import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var health: HealthService
    @State private var draft = UserProfile()
    @State private var step = 0

    private let lastStep = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
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
        case 1: levelStep
        case 2: goalStep
        case 3: scheduleStep
        default: bodyStep
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
                "Your free, private training plan. It adapts as you get stronger, and everything stays on this iPhone."
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
        }
    }

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Your experience", "We start at the right difficulty and adjust automatically after each workout.")
            ForEach(FitnessLevel.allCases) { level in
                OptionCard(
                    symbol: symbol(for: level),
                    title: level.title,
                    subtitle: level.summary,
                    selected: draft.level == level
                ) { draft.level = level }
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            header("Your goal", "This shapes reps, rest and how much cardio flow we add.")
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

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("Your schedule", "Be realistic. Consistency beats ambition.")

            Stepper(value: $draft.daysPerWeek, in: 1...6) {
                Text("**\(draft.daysPerWeek)** workout days per week")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Session length")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Session length", selection: $draft.sessionMinutes) {
                    ForEach([20, 30, 45, 60], id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            }

            Text("Equipment")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            ForEach(Equipment.allCases) { equipment in
                OptionCard(
                    symbol: equipment.symbol,
                    title: equipment.title,
                    subtitle: equipment.summary,
                    selected: draft.equipment == equipment
                ) { draft.equipment = equipment }
            }
        }
    }

    private var bodyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header("About you", "Used for calorie estimates and to pick starting weights. You can change it any time.")

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
            .padding(.top, 4)

            Label("Nothing leaves your phone. There is no account and no tracking.", systemImage: "lock.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
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
            Button(step == lastStep ? "Build my plan" : "Continue") {
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

    // MARK: Helpers

    private func symbol(for level: FitnessLevel) -> String {
        switch level {
        case .beginner: return "figure.walk"
        case .intermediate: return "figure.run"
        case .advanced: return "bolt.fill"
        }
    }

    private var weightRange: ClosedRange<Double> {
        draft.units == .metric ? 30...250 : 66...550
    }

    private var heightRange: ClosedRange<Double> {
        draft.units == .metric ? 120...230 : 48...90
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
