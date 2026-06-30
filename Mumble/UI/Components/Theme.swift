import SwiftUI

/// Centralized dark theme matching the "Flow" design language.
enum Theme {
    // Backgrounds
    static let windowBackground = Color(hex: 0x0B0B0F)
    static let sidebarBackground = Color(hex: 0x121218)
    static let panelBackground = Color(hex: 0x16161D)
    static let cardBackground = Color(hex: 0x1C1C25)
    static let elevatedBackground = Color(hex: 0x23232E)

    // Accent
    static let accent = Color(hex: 0x9474F3)
    static let accentSoft = Color(hex: 0x6E5BE0)
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0xA98BFF), Color(hex: 0x6E5BE0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Text
    static let textPrimary = Color(hex: 0xF2F2F7)
    static let textSecondary = Color(hex: 0x9A9AA8)
    static let textTertiary = Color(hex: 0x6B6B78)

    // Lines & states
    static let separator = Color.white.opacity(0.06)
    static let hover = Color.white.opacity(0.04)
    static let selection = Color(hex: 0x6E5BE0).opacity(0.22)
    static let recording = Color(hex: 0xF3576B)
    static let success = Color(hex: 0x4FCB7A)

    static let cornerRadius: CGFloat = 10
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

extension View {
    /// Standard card container used across the app.
    func flowCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.separator, lineWidth: 1)
            )
    }
}
