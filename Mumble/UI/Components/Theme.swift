import SwiftUI

/// Centralized theme with light/dark adaptive tokens and liquid glass surfaces.
enum Theme {
    // Accent (shared across appearances)
    static let accent = Color(hex: 0x8F6DFF)
    static let accentSoft = Color(hex: 0x5F46D8)
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xB79BFF), Color(hex: 0x6A4FF2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // States (shared)
    static let recording = Color(hex: 0xF3576B)
    static let success = Color(hex: 0x4FCB7A)
    static let selection = Color(hex: 0x7D5CFF).opacity(0.22)

    static let cornerRadius: CGFloat = 16

    // Legacy opaque backgrounds (fallback tints inside Material path)
    static let windowBackground = Color(hex: 0x0B0B0F)
    static let sidebarBackground = Color(hex: 0x121218)
    static let panelBackground = Color(hex: 0x16161D)
    static let cardBackgroundDark = Color(hex: 0x1C1C25)
    static let elevatedBackground = Color(hex: 0x23232E)

    // MARK: - Adaptive tokens

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xF5F2FF) : Color(hex: 0x1A1A2E)
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xB4AEC8) : Color(hex: 0x5C5C6E)
    }

    static func textTertiary(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x7C758F) : Color(hex: 0x8E8E9A)
    }

    static func cardBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.075)
            : Color.white.opacity(0.55)
    }

    static func separator(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.10)
            : Color.white.opacity(0.65)
    }

    static func glassEdge(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.13)
            : Color.white.opacity(0.55)
    }

    static func hover(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.065)
            : Color.black.opacity(0.03)
    }

    // Static aliases for views not yet migrated to adaptive tokens
    static let textPrimary = Color(hex: 0xF5F2FF)
    static let textSecondary = Color(hex: 0xB4AEC8)
    static let textTertiary = Color(hex: 0x7C758F)
    static let cardBackground = cardBackgroundDark
    static let separator = Color.white.opacity(0.10)
    static let hover = Color.white.opacity(0.065)
}

// MARK: - Dictation hotkey copy

enum DictationShortcuts {
    /// Compact symbol shown inline (Right Option key).
    static let symbol = "⌥"
    /// Full label for UI copy.
    static let holdLabel = "Right Option (⌥)"
    static let holdHint = "Hold \(holdLabel) anywhere. Release to paste."
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Appearance preference

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
