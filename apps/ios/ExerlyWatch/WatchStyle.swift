import SwiftUI

/// Exerly's dark palette, the same values as `Exerly/Theme/Colors.swift`.
enum WatchPalette {
    static let primary = Color(rgb: 0x8B5CF6)
    static let primaryText = Color(rgb: 0xA78BFA)
    static let action = Color(rgb: 0x7C3AED)
    static let accent = Color(rgb: 0xEC4899)
    static let textSecondary = Color(rgb: 0xB2ADC2)
    /// The pulse mark's own purple, from `Brand/ExerlyMark.png`.
    static let mark = Color(rgb: 0x7E41A4)

    static let ring = AngularGradient(colors: [primary, accent, primary], center: .center)
    /// The brand's glow behind every screen.
    static let background = LinearGradient(colors: [primary.opacity(0.42), action.opacity(0.12), .black],
                                           startPoint: .top, endPoint: .bottom)
}

extension Color {
    init(rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255)
    }
}

enum WatchFormat {
    /// A weight to the nearest 0.1, without trailing zeros: "140", "62.5".
    static func load(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...1)))
    }

    static func minutes(from start: Date, to end: Date) -> String {
        let minutes = max(1, Int((end.timeIntervalSince(start) / 60).rounded()))
        return "\(minutes) min"
    }
}

/// The Exerly pulse mark in its own purple on white, as on the app icon.
struct PulseMark: View {
    var size: CGFloat = 20

    var body: some View {
        Image("ExerlyPulse").resizable().scaledToFit()
            .foregroundStyle(WatchPalette.mark)
            .padding(size * 0.2)
            .frame(width: size, height: size)
            .background(.white, in: Circle())
            .accessibilityHidden(true)
    }
}

/// A small caps label above content, like the app's eyebrows.
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(0.6)
            .foregroundStyle(WatchPalette.primaryText)
    }
}

/// Live heart rate from the workout session, or a dash before the first reading.
struct HeartRateView: View {
    let bpm: Double?

    var body: some View {
        HStack(spacing: 3) {
            // One beat per reading, rather than an animation that never stops.
            Image(systemName: "heart.fill").foregroundStyle(WatchPalette.accent)
                .symbolEffect(.bounce, value: bpm)
            Text(bpm.map { "\(Int($0.rounded()))" } ?? "--")
                .font(.system(.body, design: .rounded).weight(.semibold)).monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Heart rate")
        .accessibilityValue(bpm.map { "\(Int($0.rounded())) beats per minute" } ?? "No reading yet")
        .accessibilityIdentifier("watch.heartRate")
    }
}
