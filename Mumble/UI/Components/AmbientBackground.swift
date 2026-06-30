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
            Color(hex: 0x070711)
            RadialGradient(
                colors: [Color(hex: 0x5B3DD6).opacity(0.48), .clear],
                center: .init(x: 0.13, y: 0.18),
                startRadius: 0,
                endRadius: 460
            )
            RadialGradient(
                colors: [Color(hex: 0x20125F).opacity(0.70), .clear],
                center: .init(x: 0.78, y: 0.18),
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(hex: 0x162D68).opacity(0.35), .clear],
                center: .init(x: 0.84, y: 0.82),
                startRadius: 0,
                endRadius: 380
            )
            RadialGradient(
                colors: [Color(hex: 0x8A4DFF).opacity(0.18), .clear],
                center: .init(x: 0.56, y: 0.48),
                startRadius: 0,
                endRadius: 300
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
