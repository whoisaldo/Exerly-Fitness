import SwiftUI
import UIKit

extension Color {
    static let exPrimary = adaptive(0x7C3AED, 0x8B5CF6)
    // Text and filled controls use separate purple roles for readable contrast.
    // The original brand, chart and logo colours stay unchanged.
    static let exPrimaryText = adaptive(0x7C3AED, 0xA78BFA)
    static let exActionFill = Color(hex: "7C3AED")
    static let exDestructiveFill = Color(hex: "AE2834")
    static let exSecondary = adaptive(0x9333EA, 0xA855F7)
    static let exAccent = adaptive(0xBE185D, 0xEC4899)
    static let exBackground = adaptive(0xF8F7FC, 0x0A0A0F)
    static let exSurface1 = adaptive(0xFFFFFF, 0x101016)
    static let exSurface2 = adaptive(0xF1EEF8, 0x15151D)
    static let exSurface3 = adaptive(0xE9E4F2, 0x1B1B24)
    static let exTextPrimary = adaptive(0x1D1929, 0xF7F8FA)
    static let exTextSecondary = adaptive(0x5B556A, 0xB2ADC2)
    static let exTextMuted = adaptive(0x6C6479, 0x9D96B0)
    static let exSuccess = adaptive(0x167044, 0x4ADE80)
    static let exWarning = adaptive(0x86541C, 0xFBBF24)
    static let exError = adaptive(0xAE2834, 0xFDA4AF)
    static let exInfo = adaptive(0x265F83, 0x93C5FD)
    static let exBorder = adaptive(0xD8D2E3, 0x373040)
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
    static var exPrimaryText: Color { Color.exPrimaryText }
    static var exActionFill: Color { Color.exActionFill }
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
        colors: [.exPrimary, .exSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let exAccentGradient = LinearGradient(
        colors: [.exSecondary, .exAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let exSurfaceGradient = LinearGradient(
        colors: [.exSurface1, .exBackground],
        startPoint: .top,
        endPoint: .bottom
    )
}
