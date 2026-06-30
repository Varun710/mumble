import AppKit
import SwiftUI

/// The small recording capsule shown during push-to-talk dictation.
/// Floats above all apps with liquid glass styling.
struct OverlayView: View {
    @Bindable var model: OverlayModel
    @State private var appear = false

    var body: some View {
        Group {
            if model.phase == .listening {
                OverlayListeningView(model: model)
            } else {
                DictationStatusPill(phase: pillPhase, forOverlay: true)
            }
        }
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { appear = true }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.phase)
    }

    private var pillPhase: DictationPillPhase {
        switch model.phase {
        case .listening:
            return .ready
        case .transcribing:
            return .transcribing(modelName: model.modelName)
        case .done:
            return .pasted
        case .error:
            return .error(model.message)
        }
    }
}

/// Live caption viewport — shows at most three wrapped lines and scrolls to the tail.
private enum OverlayCaptionLayout {
    static let fontSize: CGFloat = 12
    static let maxVisibleLines = 3

    static var lineHeight: CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        return ceil(font.ascender - font.descender + font.leading)
    }

    static var viewportHeight: CGFloat {
        lineHeight * CGFloat(maxVisibleLines)
    }
}

private struct CaptionContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Compact listening state — grows vertically when live captions appear.
private struct OverlayListeningView: View {
    @Bindable var model: OverlayModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false
    @State private var captionContentHeight: CGFloat = 0

    private var hasCaption: Bool {
        !model.confirmedCaption.isEmpty || !model.draftCaption.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: hasCaption ? 8 : 0) {
            HStack(spacing: 12) {
                micOrb

                VStack(alignment: .leading, spacing: 2) {
                    Text("Listening…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary(for: colorScheme))
                    Text("Speak now. Release to paste.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
                .frame(minWidth: DictationStatusPill.textMinWidth, alignment: .leading)

                Text(formatElapsed(model.elapsed))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
            }

            if hasCaption {
                captionRow
            }
        }
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(DictationPillChrome(forOverlay: true))
        .modifier(DictationPillSizing(forOverlay: true))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hasCaption)
        .onAppear { pulse = true }
    }

    private var captionRow: some View {
        Text(attributedCaption)
            .font(.system(size: OverlayCaptionLayout.fontSize))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: CaptionContentHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .onPreferenceChange(CaptionContentHeightKey.self) { captionContentHeight = $0 }
            .offset(y: captionScrollOffset)
            .animation(.easeOut(duration: 0.12), value: captionScrollOffset)
            .frame(height: OverlayCaptionLayout.viewportHeight, alignment: .top)
            .clipped()
            .padding(.top, 2)
    }

    private var captionScrollOffset: CGFloat {
        -max(0, captionContentHeight - OverlayCaptionLayout.viewportHeight)
    }

    private var attributedCaption: AttributedString {
        var result = AttributedString()
        if !model.confirmedCaption.isEmpty {
            var confirmed = AttributedString(model.confirmedCaption)
            confirmed.foregroundColor = Theme.textPrimary(for: colorScheme)
            result.append(confirmed)
        }
        if !model.draftCaption.isEmpty {
            if !result.characters.isEmpty {
                var space = AttributedString(" ")
                space.foregroundColor = Theme.textSecondary(for: colorScheme)
                result.append(space)
            }
            var draft = AttributedString(model.draftCaption)
            draft.foregroundColor = Theme.textSecondary(for: colorScheme)
            result.append(draft)
        }
        return result
    }

    private var micOrb: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.35), lineWidth: 1.5)
                .frame(width: 34, height: 34)
                .scaleEffect(pulse ? 1.35 : 1.0)
                .opacity(pulse ? 0 : 0.75)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)

            Circle()
                .fill(Theme.accentGradient)
                .frame(width: 34, height: 34)
                .shadow(color: Theme.accent.opacity(0.4), radius: 8)

            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
