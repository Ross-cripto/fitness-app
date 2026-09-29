import SwiftUI

/// "🔥 453 cal" style metric used at the top of Workouts and in the workout hero.
struct StatPill: View {
    let symbol: String
    let value: String
    let unit: String
    let tint: Color
    var large = true
    var onDark = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbol)
                .scaledFont(size: large ? 20 : 16, weight: .bold)
                .foregroundStyle(tint)
            Text(value)
                .scaledFont(size: large ? 26 : 20, weight: .bold, design: .rounded)
                .foregroundStyle(onDark ? Color.white : Color.primary)
            Text(unit)
                .scaledFont(size: large ? 13 : 12, weight: .medium)
                .lineLimit(1)
                .foregroundStyle(onDark ? Color.white.opacity(0.6) : Color.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Full-bleed workout card with a themed gradient in place of a photo.
struct WorkoutCard: View {
    let label: String
    let workout: Workout
    let weightKg: Double
    /// The card grows with the text size so large text is not cut off.
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 136

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: workout.theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            Image(systemName: workout.theme.symbol)
                .scaledFont(size: 120, weight: .regular)
                .foregroundStyle(Color.white.opacity(0.10))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 28)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .scaledFont(size: 11, weight: .semibold)
                        .foregroundStyle(Theme.pink)
                    Text(workout.title)
                        .scaledFont(size: 19, weight: .semibold)
                        .foregroundStyle(.white)
                    HStack(spacing: 10) {
                        Text(L("{0} min", workout.minutes))
                        Text(L("{0} cal", workout.calories(weightKg: weightKg)))
                    }
                    .scaledFont(size: 12, weight: .medium)
                    .foregroundStyle(Color.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct PillButtonStyle: ButtonStyle {
    var tint: Color = Theme.pink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaledFont(size: 16, weight: .bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(Capsule().fill(tint))
            .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// White rounded card with the soft shadow used on the Progress screen.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .shadow(color: Theme.cardShadow, radius: 14, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

struct IconBadge: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .scaledFont(size: size * 0.45, weight: .bold)
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(tint))
    }
}

struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(6, proxy.size.width * CGFloat(min(1, max(0, value)))))
            }
        }
        .frame(height: 6)
    }
}

func formatClock(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}

/// Mon-Sun row: filled = trained, ring = scheduled, faint ring = rest day.
struct WeekStrip: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        let calendar = PlanGenerator.calendar
        let today = calendar.startOfDay(for: Date())
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }

        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let done = !store.sessions(on: day).isEmpty
                let scheduled = PlanGenerator.isTrainingDay(day, profile: store.profile)
                let isToday = calendar.isDate(day, inSameDayAs: today)
                VStack(spacing: 6) {
                    Text(Loc.date(day, "EEEEE"))
                        .scaledFont(size: 12, weight: isToday ? .bold : .medium)
                        .foregroundStyle(isToday ? Theme.pink : Color.secondary)
                    ZStack {
                        Circle().fill(done ? Theme.pink : Color.clear)
                        Circle().stroke(scheduled || done ? Theme.pink : Color.primary.opacity(0.12), lineWidth: 2)
                        if done {
                            Image(systemName: "checkmark")
                                .scaledFont(size: 12, weight: .bold)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary(days: days))
    }

    private func accessibilitySummary(days: [Date]) -> String {
        days.map { day in
            let name = Loc.date(day, "EEE")
            if !store.sessions(on: day).isEmpty { return L("{0} trained", name) }
            return PlanGenerator.isTrainingDay(day, profile: store.profile) ? L("{0} scheduled", name) : L("{0} rest", name)
        }.joined(separator: ", ")
    }
}
