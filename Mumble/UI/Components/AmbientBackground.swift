import SwiftUI

/// Full-window static gradient behind glass panels.
struct AmbientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if colorScheme == .dark {
                darkBackground
            } else {
                lightBackground
            }
        }
        .ignoresSafeArea()
    }

    private var darkBackground: some View {
        ZStack {
            Color(hex: 0x0A0A12)
            RadialGradient(
                colors: [Color(hex: 0x3D2B8E).opacity(0.55), .clear],
                center: .init(x: 0.15, y: 0.2),
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(hex: 0x1E3A6E).opacity(0.45), .clear],
                center: .init(x: 0.85, y: 0.75),
                startRadius: 0,
                endRadius: 380
            )
            RadialGradient(
                colors: [Color(hex: 0x5C3D7A).opacity(0.35), .clear],
                center: .init(x: 0.55, y: 0.45),
                startRadius: 0,
                endRadius: 320
            )
        }
    }

    private var lightBackground: some View {
        ZStack {
            Color(hex: 0xF4F0FA)
            RadialGradient(
                colors: [Color(hex: 0xC8B6FF).opacity(0.55), .clear],
                center: .init(x: 0.2, y: 0.15),
                startRadius: 0,
                endRadius: 400
            )
            RadialGradient(
                colors: [Color(hex: 0xFFB8D9).opacity(0.4), .clear],
                center: .init(x: 0.8, y: 0.3),
                startRadius: 0,
                endRadius: 360
            )
            RadialGradient(
                colors: [Color(hex: 0xA8D4FF).opacity(0.45), .clear],
                center: .init(x: 0.5, y: 0.85),
                startRadius: 0,
                endRadius: 340
            )
        }
    }
}
