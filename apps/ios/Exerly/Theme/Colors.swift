import SwiftUI
import UIKit

extension Color {
    static let exPrimary = adaptive(0x176344, 0x82D6B6)
    static let exSecondary = adaptive(0x265F72, 0x9CCFE1)
    static let exAccent = adaptive(0x855B22, 0xE5BF7A)
    static let exBackground = adaptive(0xF5F6F3, 0x0B1519)
    static let exSurface1 = adaptive(0xFFFFFF, 0x112026)
    static let exSurface2 = adaptive(0xEEF1EC, 0x192B31)
    static let exSurface3 = adaptive(0xE3E9E1, 0x253940)
    static let exTextPrimary = adaptive(0x162924, 0xEDF4EF)
    static let exTextSecondary = adaptive(0x4C635A, 0xACBFB7)
    static let exTextMuted = adaptive(0x5B6C64, 0x94AAA0)
    static let exSuccess = adaptive(0x176344, 0x82D6B6)
    static let exWarning = adaptive(0x86541C, 0xE9C07E)
    static let exError = adaptive(0xAE2834, 0xFF9A9F)
    static let exInfo = adaptive(0x265F83, 0x99CCEC)
    static let exBorder = adaptive(0xCFD9D0, 0x344C43)
    static let exBorderFocused = exPrimary
    static let exGlassBg = exSurface1
    static let exGlassBorder = exBorder

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((rgb >> 16) & 255) / 255,
                           green: CGFloat((rgb >> 8) & 255) / 255,
                           blue: CGFloat(rgb & 255) / 255, alpha: 1)
        })
    }
}

// MARK: - ShapeStyle Convenience

extension ShapeStyle where Self == Color {
    static var exPrimary: Color { Color.exPrimary }
    static var exSecondary: Color { Color.exSecondary }
    static var exAccent: Color { Color.exAccent }
    static var exBackground: Color { Color.exBackground }
    static var exSurface1: Color { Color.exSurface1 }
    static var exSurface2: Color { Color.exSurface2 }
    static var exSurface3: Color { Color.exSurface3 }
    static var exTextPrimary: Color { Color.exTextPrimary }
    static var exTextSecondary: Color { Color.exTextSecondary }
    static var exTextMuted: Color { Color.exTextMuted }
    static var exSuccess: Color { Color.exSuccess }
    static var exWarning: Color { Color.exWarning }
    static var exError: Color { Color.exError }
    static var exInfo: Color { Color.exInfo }
    static var exBorder: Color { Color.exBorder }
    static var exBorderFocused: Color { Color.exBorderFocused }
    static var exGlassBg: Color { Color.exGlassBg }
    static var exGlassBorder: Color { Color.exGlassBorder }
}

// MARK: - Hex Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradients

extension LinearGradient {
    static let exPrimaryGradient = LinearGradient(
        colors: [Color(hex: "176344"), Color(hex: "176344")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let exAccentGradient = LinearGradient(
        colors: [Color(hex: "265F72"), Color(hex: "265F72")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let exSurfaceGradient = LinearGradient(
        colors: [.exSurface1, .exBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}
