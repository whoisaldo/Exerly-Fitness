import SwiftUI
import WidgetKit

/// Exerly's dark palette, the same values as the app's dark appearance in
/// `Exerly/Theme/Colors.swift`. Widgets and the Live Activity always sit on
/// Exerly's dark surfaces.
enum WidgetPalette {
    static let primary = Color(rgb: 0x8B5CF6)
    static let primaryText = Color(rgb: 0xA78BFA)
    static let actionFill = Color(rgb: 0x7C3AED)
    static let secondary = Color(rgb: 0xA855F7)
    static let accent = Color(rgb: 0xEC4899)
    static let background = Color(rgb: 0x0A0A0F)
    static let surface = Color(rgb: 0x101016)
    static let surface2 = Color(rgb: 0x15151D)
    static let textPrimary = Color(rgb: 0xF7F8FA)
    static let textSecondary = Color(rgb: 0xB2ADC2)
    static let textMuted = Color(rgb: 0x9D96B0)
    static let success = Color(rgb: 0x4ADE80)
    /// The pulse mark's own purple, from `Brand/ExerlyMark.png`.
    static let mark = Color(rgb: 0x7E41A4)

    static let ring = AngularGradient(colors: [primary, secondary, accent, primary], center: .center)
    static let rest = LinearGradient(colors: [primary, accent], startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255)
    }
}

/// The Exerly pulse mark, cut from its tile.
struct PulseMark: View {
    var size: CGFloat = 16

    var body: some View {
        Image("ExerlyPulse").resizable().scaledToFit()
            .foregroundStyle(WidgetPalette.mark)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// The dark surface behind every widget, with the brand's purple glow.
struct WidgetSurface: View {
    var body: some View {
        ZStack {
            WidgetPalette.surface
            RadialGradient(colors: [WidgetPalette.primary.opacity(0.22), .clear],
                           center: UnitPoint(x: 0, y: 0), startRadius: 0, endRadius: 220)
            RadialGradient(colors: [WidgetPalette.accent.opacity(0.1), .clear],
                           center: UnitPoint(x: 1, y: 1), startRadius: 0, endRadius: 200)
        }
    }
}

/// A small caps label above a widget's content, like the app's eyebrows.
struct WidgetEyebrow: View {
    let text: String
    var color: Color = WidgetPalette.primaryText

    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(0.6)
            .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// A thin bar of progress toward a target.
struct WidgetBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.18))
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

enum WidgetFormat {
    static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
}
