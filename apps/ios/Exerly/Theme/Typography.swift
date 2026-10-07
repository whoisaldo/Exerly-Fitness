import SwiftUI

// MARK: - Typography Scale

extension Font {
    static let exDisplay = Font.system(.largeTitle, design: .default, weight: .bold)
    static let exH1 = Font.system(.largeTitle, design: .default, weight: .bold)
    static let exH2 = Font.system(.title2, design: .default, weight: .semibold)
    static let exH3 = Font.system(.title3, design: .default, weight: .semibold)
    static let exBody = Font.system(.body, design: .default, weight: .regular)
    static let exBodyMedium = Font.system(.body, design: .default, weight: .medium)
    static let exLabel = Font.system(.subheadline, design: .default, weight: .medium)
    static let exCaption = Font.system(.caption, design: .default, weight: .regular)
    static let exSmall = Font.system(.caption, design: .default, weight: .regular)

    // Proportional figures for reading; reserve mono for timers and aligned data.
    static let exStat = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let exStatMedium = Font.system(.title2, design: .rounded, weight: .semibold)
    static let exStatSmall = Font.system(.body, design: .rounded, weight: .semibold)
    static let exMono = Font.system(.subheadline, design: .monospaced, weight: .regular)
}

// MARK: - Text Style Modifier

struct ExTextStyle: ViewModifier {
    let font: Font
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundStyle(color)
    }
}

extension View {
    func exTextStyle(_ font: Font, color: Color = .exTextPrimary) -> some View {
        modifier(ExTextStyle(font: font, color: color))
    }
}
