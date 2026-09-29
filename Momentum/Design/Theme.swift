import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    /// Calories / primary actions.
    static let pink = Color(hex: 0xFF2D6B)
    /// Duration / success.
    static let green = Color(hex: 0x34C759)
    /// Selected date chip.
    static let blue = Color(hex: 0x2033D9)
    static let amber = Color(hex: 0xFF9F0A)

    static let cardShadow = Color.black.opacity(0.08)
}

extension MuscleGroup {
    /// Dark two-stop gradient used in place of photography.
    var colors: [Color] {
        switch self {
        case .chest: return [Color(hex: 0x5B2A3A), Color(hex: 0x14121A)]
        case .back: return [Color(hex: 0x2A3F5F), Color(hex: 0x10131A)]
        case .legs: return [Color(hex: 0x4A3A2A), Color(hex: 0x14110E)]
        case .shoulders: return [Color(hex: 0x3D2F5C), Color(hex: 0x12101A)]
        case .arms: return [Color(hex: 0x5C3A2A), Color(hex: 0x15100E)]
        case .core: return [Color(hex: 0x2A5C4F), Color(hex: 0x0E1714)]
        case .cardio: return [Color(hex: 0x6B2438), Color(hex: 0x150C10)]
        case .fullBody: return [Color(hex: 0x3A3F52), Color(hex: 0x0F1015)]
        case .mobility: return [Color(hex: 0x2A4F5C), Color(hex: 0x0D1519)]
        }
    }
}

// MARK: - Dynamic Type

/// A system font of a given design size that still follows the person's text-size setting
/// (`Font.system(size:)` alone never scales).
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design))
    }
}
