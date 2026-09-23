import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

/// High-contrast light theme: team A red, team B blue.
enum Theme {
    static let paper = Color(hex: 0xF3F5FA)
    static let card = Color.white
    static let ink = Color(hex: 0x1F2537)
    static let muted = Color(hex: 0x687086)
    static let line = Color(hex: 0xE3E7EF)
    static let field = Color(hex: 0xEEF1F7)

    static let red = Color(hex: 0xD9363B)
    static let redDeep = Color(hex: 0xB3262B)
    static let redSoft = Color(hex: 0xFFF1F1)
    static let redMid = Color(hex: 0xFBCFD0)

    static let blue = Color(hex: 0x2563EB)
    static let blueDeep = Color(hex: 0x1D4ED8)
    static let blueSoft = Color(hex: 0xEEF4FF)
    static let blueMid = Color(hex: 0xCADBFD)

    static let sun = Color(hex: 0xFFC53D)
    static let sunDeep = Color(hex: 0xE5A000)
    static let danger = Color(hex: 0xC62828)

    static func team(_ s: Side) -> Color { s == .A ? red : blue }
    static func teamDeep(_ s: Side) -> Color { s == .A ? redDeep : blueDeep }
    static func teamSoft(_ s: Side) -> Color { s == .A ? redSoft : blueSoft }
    static func teamMid(_ s: Side) -> Color { s == .A ? redMid : blueMid }
}

extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    var height: CGFloat = 52
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(17))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: height)
            .frame(maxWidth: .infinity)
            .background(tint, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(16, .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 18)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity)
            .background(Theme.field, in: .rect(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    func card() -> some View {
        padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 18))
            .shadow(color: Theme.ink.opacity(0.07), radius: 12, y: 6)
    }
}
