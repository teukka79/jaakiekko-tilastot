import SwiftUI

// Midnight Ice -teema: tumma, sinertävä, pehmeät liukuvärit ja lasipaneelit.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let cyan = Color(hex: 0x22D3EE)
    static let cyanDeep = Color(hex: 0x0E7490)
    static let blue = Color(hex: 0x2563EB)
    static let indigo = Color(hex: 0x6366F1)
    static let amber = Color(hex: 0xFBBF24)
    static let green = Color(hex: 0x4ADE80)
    static let red = Color(hex: 0xF87171)
    static let text = Color(hex: 0xF1F5F9)
    static let muted = Color(hex: 0x94A3B8)
    static let hairline = Color(hex: 0x93C5FD, opacity: 0.12)

    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x0E7490), Color(hex: 0x2563EB), Color(hex: 0x4F46E5)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x08112A), Color(hex: 0x050A18), Color(hex: 0x030612)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(hex: 0x22D3EE, opacity: 0.16), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 650)
            RadialGradient(colors: [Color(hex: 0x6366F1, opacity: 0.18), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 650)
            RadialGradient(colors: [Color(hex: 0x0E7490, opacity: 0.20), .clear],
                           center: .bottom, startRadius: 0, endRadius: 700)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x1E2D52, opacity: 0.55), Color(hex: 0x0F1730, opacity: 0.65)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

extension View {
    func glassCard(radius: CGFloat = 16) -> some View { modifier(GlassCard(radius: radius)) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var active = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color(hex: 0xCBD5E1))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Color.white.opacity(configuration.isPressed ? 0.10 : 0.05)))
            )
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// Joukkueen lyhennemerkki, kun logoa ei ole tai se ei lataudu.
struct TeamBadge: View {
    let name: String
    let abbr: String

    private var hue: Double {
        let v = name.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 360 }
        return Double(v) / 360
    }

    var body: some View {
        GeometryReader { geo in
            Text(abbr)
                .font(.system(size: max(9, geo.size.width * 0.3), weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hue: hue, saturation: 0.55, brightness: 0.42),
                            in: RoundedRectangle(cornerRadius: geo.size.width * 0.22, style: .continuous))
        }
        .accessibilityHidden(true)
    }
}
