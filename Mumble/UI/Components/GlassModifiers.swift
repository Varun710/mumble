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
            .background(
                Color(hex: 0x111026).opacity(colorScheme == .dark ? 0.26 : 0.08),
                in: shape
            )
            .overlay(shape.strokeBorder(Theme.glassEdge(for: colorScheme), lineWidth: 1))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 24, y: 18)
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

// MARK: - Below-anchored dropdowns

struct BelowDropdown<Label: View, Content: View>: View {
    var minWidth: CGFloat = 140
    @ViewBuilder let label: () -> Label
    @ViewBuilder let content: (_ dismiss: @escaping () -> Void) -> Content
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                label()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
            }
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .top
        ) {
            VStack(alignment: .leading, spacing: 4) {
                content { isPresented = false }
            }
            .padding(8)
            .frame(minWidth: minWidth, alignment: .leading)
        }
    }
}

struct BelowDropdownPicker<Value: Hashable, Label: View, RowContent: View>: View {
    @Binding var selection: Value
    let values: [Value]
    var minWidth: CGFloat = 140
    var isDisabled: (Value) -> Bool = { _ in false }
    var onSelect: (Value) -> Void = { _ in }
    @ViewBuilder let label: (Value) -> Label
    @ViewBuilder let rowContent: (Value, Bool) -> RowContent
    @Environment(\.colorScheme) private var colorScheme

    init(
        selection: Binding<Value>,
        values: [Value],
        minWidth: CGFloat = 140,
        @ViewBuilder label: @escaping (Value) -> Label,
        @ViewBuilder rowContent: @escaping (Value, Bool) -> RowContent,
        isDisabled: @escaping (Value) -> Bool = { _ in false },
        onSelect: @escaping (Value) -> Void = { _ in }
    ) {
        self._selection = selection
        self.values = values
        self.minWidth = minWidth
        self.label = label
        self.rowContent = rowContent
        self.isDisabled = isDisabled
        self.onSelect = onSelect
    }

    var body: some View {
        BelowDropdown(minWidth: minWidth) {
            label(selection)
        } content: { dismiss in
            ForEach(values, id: \.self) { value in
                let isSelected = value == selection
                Button {
                    selection = value
                    onSelect(value)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        rowContent(value, isSelected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isSelected ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDisabled(value))
            }
        }
        .fixedSize()
    }
}
