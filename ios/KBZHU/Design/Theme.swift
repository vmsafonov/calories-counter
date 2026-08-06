import SwiftUI
import UIKit
import CoreText

// MARK: - Colours
// Values transcribed 1:1 from the Claude Design prototype (`Трекер КБЖУ.dc.html`).

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Theme {
    // Base
    static let ink = Color(hex: 0x1A1D1B)
    static let green = Color(hex: 0x22A45C)
    static let greenDark = Color(hex: 0x177F47)
    static let surface = Color.white
    static let softCard = Color(hex: 0xF4F6F3)
    static let greenTint = Color(hex: 0xE9F6EE)
    static let greenTintSoft = Color(hex: 0xF3FAF5)
    static let toastAccent = Color(hex: 0x7BE0A6)
    static let danger = Color(hex: 0xC9553A)

    // Macro palette
    static let proteinText = Color(hex: 0x2E6FA8)
    static let proteinBar = Color(hex: 0x3F86C9)
    static let proteinTint = Color(hex: 0xE9F1FA)

    static let fatText = Color(hex: 0xA9761A)
    static let fatBar = Color(hex: 0xDFA330)
    static let fatTint = Color(hex: 0xFBF2DF)

    static let carbText = Color(hex: 0x7A4FB3)
    static let carbBar = Color(hex: 0x9E6FD3)
    static let carbTint = Color(hex: 0xF3ECFB)

    static let overText = Color(hex: 0xC0761B)

    // Scanner
    static let scanBackdrop = Color(hex: 0x141715)
    static let scanLine = Color(hex: 0x4ADE80)
    /// Статус «код не найден».
    static let scanWarning = Color(hex: 0xF0B45C)

    /// Ink at a given alpha — the prototype's `rgba(26,29,27,.xx)`.
    static func ink(_ opacity: Double) -> Color { Color(hex: 0x1A1D1B, opacity: opacity) }

    static let hairline = Color(hex: 0x1A1D1B, opacity: 0.07)
    static let hairlineStrong = Color(hex: 0x1A1D1B, opacity: 0.09)
    static let fill = Color(hex: 0x1A1D1B, opacity: 0.045)
}

// MARK: - Typography

enum Golos {
    /// PostScript names of the bundled static instances.
    private static let postScriptNames: [Int: String] = [
        400: "GolosText-Regular",
        500: "GolosText-Medium",
        600: "GolosText-SemiBold",
        700: "GolosText-Bold",
        800: "GolosText-ExtraBold"
    ]

    /// Weights that actually resolved after registration; empty until `registerFonts()` runs.
    private static var resolved: [Int: String] = [:]

    /// Registers the bundled TTFs with Core Text. Called once at launch, so the app does not
    /// depend on an `UIAppFonts` entry in Info.plist.
    static func registerFonts() {
        guard resolved.isEmpty else { return }
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls where url.lastPathComponent.hasPrefix("GolosText") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        for (weight, name) in postScriptNames where UIFont(name: name, size: 12) != nil {
            resolved[weight] = name
        }
    }

    private static func systemWeight(_ weight: Int) -> UIFont.Weight {
        switch weight {
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        default: return .regular
        }
    }

    private static func fontWeight(_ weight: Int) -> Font.Weight {
        switch weight {
        case 500: return .medium
        case 600: return .semibold
        case 700: return .bold
        case 800: return .heavy
        default: return .regular
        }
    }

    /// A Golos Text face, falling back to the system face when the font is missing.
    static func font(_ weight: Int, _ size: CGFloat) -> Font {
        if let name = resolved[weight] {
            return .custom(name, fixedSize: size)
        }
        return .system(size: size, weight: fontWeight(weight))
    }

    static func uiFont(_ weight: Int, _ size: CGFloat) -> UIFont {
        if let name = resolved[weight], let font = UIFont(name: name, size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: systemWeight(weight))
    }
}

extension View {
    /// Mirrors the prototype's `font: <weight> <size>/<line-height>` shorthand.
    func golos(_ weight: Int, _ size: CGFloat, lineHeight: CGFloat? = nil) -> some View {
        // SwiftUI spaces lines by the font's own leading; nudge it to the design's value.
        let extraLeading: CGFloat = lineHeight.map { value in
            max(0, size * value - Golos.uiFont(weight, size).lineHeight)
        } ?? 0
        return self.font(Golos.font(weight, size)).lineSpacing(extraLeading)
    }

    /// Tabular figures, used everywhere numbers line up in the design.
    func tabularNumbers() -> some View {
        self.monospacedDigit()
    }
}
