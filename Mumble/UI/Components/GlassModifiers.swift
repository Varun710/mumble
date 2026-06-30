import SwiftUI

// MARK: - Glass panel (Tier 2: navigation shells)

extension View {
    /// Frosted glass panel for sidebars, floating controls, and status pills.
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat = 20) -> some View {
        if #available(macOS 26, *) {
            modifier(NativeGlassPanelModifier(cornerRadius: cornerRadius))
        } else {
            modifier(LegacyGlassPanelModifier(cornerRadius: cornerRadius))
        }
    }

    /// Semi-transparent content surface — no blur, avoids glass-on-glass stacking.
    func contentCard(padding: CGFloat = 16, cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        modifier(ContentCardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    /// Backward-compatible alias during migration.
    func flowCard(padding: CGFloat = 16) -> some View {
        contentCard(padding: padding)
    }
}

@available(macOS 26, *)
private struct NativeGlassPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .glassEffect(.regular, in: shape)
    }
}

private struct LegacyGlassPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(Theme.glassEdge(for: colorScheme), lineWidth: 1))
    }
}

private struct ContentCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let padding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .background(Theme.cardBackground(for: colorScheme), in: shape)
            .overlay(shape.strokeBorder(Theme.separator(for: colorScheme), lineWidth: 1))
    }
}

// MARK: - Glass effect container (macOS 26+)

/// Groups glass elements for consistent sampling on macOS 26+.
struct MumbleGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
