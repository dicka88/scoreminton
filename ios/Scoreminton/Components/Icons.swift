import SwiftUI

/// Shuttlecock glyph: skirt outline + filled cork (24×24 design grid).
struct Shuttlecock: View {
    var color: Color = .primary
    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            var skirt = Path()
            skirt.move(to: CGPoint(x: 7 * s, y: 3 * s))
            skirt.addLine(to: CGPoint(x: 17 * s, y: 3 * s))
            skirt.addLine(to: CGPoint(x: 15 * s, y: 14 * s))
            skirt.addLine(to: CGPoint(x: 9 * s, y: 14 * s))
            skirt.closeSubpath()
            ctx.stroke(skirt, with: .color(color), style: StrokeStyle(lineWidth: 2 * s, lineJoin: .round))
            var cork = Path()
            cork.move(to: CGPoint(x: 8.5 * s, y: 14 * s))
            cork.addLine(to: CGPoint(x: 15.5 * s, y: 14 * s))
            cork.addLine(to: CGPoint(x: 15.5 * s, y: 16.5 * s))
            cork.addArc(center: CGPoint(x: 12 * s, y: 16.5 * s), radius: 3.5 * s,
                        startAngle: .zero, endAngle: .degrees(180), clockwise: false)
            cork.closeSubpath()
            ctx.fill(cork, with: .color(color))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// App mark: red/blue split circle with a white shuttlecock.
struct Logo: View {
    var body: some View {
        ZStack {
            Circle().fill(Theme.red)
            Circle().fill(Theme.blue).mask(HStack(spacing: 0) { Color.clear; Color.black })
            Shuttlecock(color: .white).padding(4)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct Trophy: View {
    var body: some View {
        Image(systemName: "trophy.fill")
            .font(.system(size: 52))
            .foregroundStyle(Theme.sun, Theme.sunDeep)
            .shadow(color: Theme.sunDeep.opacity(0.4), radius: 8, y: 4)
            .accessibilityHidden(true)
    }
}

/// Falling confetti pieces, deterministic layout.
struct Confetti: View {
    private static let colors = [Theme.red, Theme.blue, Theme.sun, Theme.redMid, Theme.blueMid]
    @State private var fall = false

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<28, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Self.colors[i % Self.colors.count])
                    .frame(width: 8, height: 12)
                    .rotationEffect(.degrees(fall ? Double(i * 47 % 360) + 360 : 0))
                    .position(
                        x: geo.size.width * CGFloat((i * 37) % 100) / 100,
                        y: fall ? geo.size.height + 20 : -20
                    )
                    .animation(
                        .easeIn(duration: 1.8 + Double(i % 5) * 0.25).delay(Double(i % 7) * 0.12),
                        value: fall
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fall = true }
    }
}
