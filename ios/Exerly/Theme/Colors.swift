import SwiftUI

// MARK: - Design Tokens

extension Color {
    // Brand
    static let exPrimary = Color(hex: "8b5cf6")
    static let exSecondary = Color(hex: "a855f7")
    static let exAccent = Color(hex: "ec4899")

    // Surfaces
    static let exBackground = Color(hex: "080810")
    static let exSurface1 = Color(hex: "0f0f1a")
    static let exSurface2 = Color(hex: "161625")
    static let exSurface3 = Color(hex: "1e1e30")

    // Text
    static let exTextPrimary = Color(hex: "f8fafc")
    static let exTextSecondary = Color(hex: "94a3b8")
    static let exTextMuted = Color(hex: "475569")

    // Status
    static let exSuccess = Color(hex: "22c55e")
    static let exWarning = Color(hex: "f59e0b")
    static let exError = Color(hex: "ef4444")
    static let exInfo = Color(hex: "3b82f6")

    // Borders
    static let exBorder = Color.white.opacity(0.06)
    static let exBorderFocused = Color(hex: "8b5cf6").opacity(0.5)

    // Glass
    static let exGlassBg = Color.white.opacity(0.03)
    static let exGlassBorder = Color.white.opacity(0.06)
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
        colors: [Color(hex: "8b5cf6"), Color(hex: "a855f7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let exAccentGradient = LinearGradient(
        colors: [Color(hex: "ec4899"), Color(hex: "f43f5e")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let exSurfaceGradient = LinearGradient(
        colors: [Color(hex: "0f0f1a"), Color(hex: "161625")],
        startPoint: .top,
        endPoint: .bottom
    )
}
