import SwiftUI

// MARK: - Typography Scale

extension Font {
    static let exDisplay = Font.system(size: 48, weight: .bold, design: .rounded)
    static let exH1 = Font.system(size: 32, weight: .bold, design: .rounded)
    static let exH2 = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let exH3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let exBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let exBodyMedium = Font.system(size: 16, weight: .medium, design: .rounded)
    static let exLabel = Font.system(size: 14, weight: .medium, design: .rounded)
    static let exCaption = Font.system(size: 12, weight: .regular, design: .rounded)
    static let exSmall = Font.system(size: 11, weight: .regular, design: .rounded)

    // Mono for stats/numbers
    static let exStat = Font.system(size: 32, weight: .bold, design: .monospaced)
    static let exStatMedium = Font.system(size: 24, weight: .semibold, design: .monospaced)
    static let exStatSmall = Font.system(size: 16, weight: .medium, design: .monospaced)
    static let exMono = Font.system(size: 14, weight: .regular, design: .monospaced)
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
