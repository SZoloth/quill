import SwiftUI

// Catppuccin Mocha theme colors (matching ghostty config)
// https://github.com/catppuccin/catppuccin
struct Theme {
    // Base colors
    static let base = Color(hex: "1e1e2e")       // Background
    static let mantle = Color(hex: "181825")     // Darker background
    static let crust = Color(hex: "11111b")      // Darkest background
    static let surface0 = Color(hex: "313244")   // Surface
    static let surface1 = Color(hex: "45475a")   // Surface lighter
    static let surface2 = Color(hex: "585b70")   // Surface lightest

    // Text colors
    static let text = Color(hex: "cdd6f4")       // Primary text
    static let subtext1 = Color(hex: "bac2de")   // Secondary text
    static let subtext0 = Color(hex: "a6adc8")   // Tertiary text
    static let overlay2 = Color(hex: "9399b2")   // Muted text
    static let overlay1 = Color(hex: "7f849c")   // More muted
    static let overlay0 = Color(hex: "6c7086")   // Most muted

    // Accent colors (Claude Code orange as primary)
    static let peach = Color(hex: "fab387")      // Claude Code orange
    static let rosewater = Color(hex: "f5e0dc")
    static let flamingo = Color(hex: "f2cdcd")
    static let pink = Color(hex: "f5c2e7")
    static let mauve = Color(hex: "cba6f7")
    static let red = Color(hex: "f38ba8")
    static let maroon = Color(hex: "eba0ac")
    static let yellow = Color(hex: "f9e2af")
    static let green = Color(hex: "a6e3a1")
    static let teal = Color(hex: "94e2d5")
    static let sky = Color(hex: "89dceb")
    static let sapphire = Color(hex: "74c7ec")
    static let blue = Color(hex: "89b4fa")
    static let lavender = Color(hex: "b4befe")

    // Semantic colors
    static let primary = peach                    // Claude Code orange
    static let background = base
    static let secondaryBackground = mantle
    static let tertiaryBackground = surface0
    static let cardBackground = surface0
    static let primaryText = text
    static let secondaryText = subtext0
    static let mutedText = overlay0
    static let border = surface1
    static let accent = peach
    static let success = green
    static let warning = yellow
    static let error = red
    static let info = blue
    static let annotationHighlight = mauve
    static let annotationHighlightSelected = lavender

    // MARK: - Spacing tokens
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // MARK: - Corner radius tokens
    static let radiusSM: CGFloat = 4
    static let radiusMD: CGFloat = 6
    static let radiusLG: CGFloat = 8
    static let radiusPill: CGFloat = 12

    // MARK: - Pill component tokens
    static let pillPaddingH: CGFloat = 10
    static let pillPaddingV: CGFloat = 5

    // MARK: - Shadow presets
    struct Shadow {
        static let subtle = (color: Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let card = (color: Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let elevated = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }

    // MARK: - Editor tokens
    static let editorLineSpacing: CGFloat = 6
    static let editorFontSize: CGFloat = 15
    static let editorInsetH: CGFloat = 16
    static let editorInsetV: CGFloat = 16
    static let titleFontSize: CGFloat = 28
    static let titleBottomPadding: CGFloat = 24
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
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

// NSColor extension for theme
extension NSColor {
    static let themeBase = NSColor(Theme.base)
    static let themeMantle = NSColor(Theme.mantle)
    static let themeSurface = NSColor(Theme.surface0)
    static let themeText = NSColor(Theme.text)
    static let themeSubtext = NSColor(Theme.subtext0)
    static let themePrimary = NSColor(Theme.primary)
}
