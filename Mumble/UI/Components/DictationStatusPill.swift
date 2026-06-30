import SwiftUI

enum DictationPillPhase: Equatable {
    case ready
    case transcribing(modelName: String)
    case pasted
    case error(String)
}

/// Compact glass pill for push-to-talk status — shared across home hover and the floating overlay.
struct DictationStatusPill: View {
    var phase: DictationPillPhase = .ready
    /// When true, glass is provided by the AppKit `NSGlassEffectView` / `NSVisualEffectView` container.
    var forOverlay = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            leadingIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(minWidth: Self.textMinWidth, alignment: .leading)

            Text("Local only")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.cardBackground(for: colorScheme), in: Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.clear)
        .modifier(DictationPillChrome(forOverlay: forOverlay))
        .modifier(DictationPillSizing(forOverlay: forOverlay))
    }

    // MARK: - Content

    private var title: String {
        switch phase {
        case .ready: return "Ready for push-to-talk"
        case .transcribing: return "Transcribing…"
        case .pasted: return "Pasted"
        case .error: return "Something went wrong"
        }
    }

    private var subtitle: String {
        switch phase {
        case .ready: return DictationShortcuts.holdHint
        case .transcribing(let modelName):
            return modelName.isEmpty ? "Running locally on your Mac" : modelName
        case .pasted: return "Inserted at your cursor"
        case .error(let message):
            return message.isEmpty ? "Try again in a moment" : message
        }
    }

    @ViewBuilder
    private var leadingIcon: some View {
        ZStack {
            switch phase {
            case .pasted:
                Circle()
                    .fill(Theme.success)
                    .frame(width: 34, height: 34)
                    .shadow(color: Theme.success.opacity(0.4), radius: 8)
            case .error:
                Circle()
                    .fill(Theme.recording)
                    .frame(width: 34, height: 34)
                    .shadow(color: Theme.recording.opacity(0.4), radius: 8)
            default:
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 34, height: 34)
                    .shadow(color: Theme.accent.opacity(0.4), radius: 8)
            }

            switch phase {
            case .ready:
                Image(systemName: "mic.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            case .transcribing:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            case .pasted:
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            case .error:
                Image(systemName: "exclamationmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    /// Keeps transcribing / pasted pills the same width as the ready state.
    static let textMinWidth: CGFloat = 248
}

struct DictationPillChrome: ViewModifier {
    var forOverlay = false

    func body(content: Content) -> some View {
        let bordered = content
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.45), Theme.accentSoft.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

        if forOverlay {
            bordered
        } else {
            bordered
                .shadow(color: Theme.accent.opacity(0.12), radius: 14, y: 6)
                .glassPanel(cornerRadius: 22)
        }
    }
}

struct DictationPillSizing: ViewModifier {
    var forOverlay = false

    func body(content: Content) -> some View {
        if forOverlay {
            content
                .frame(width: OverlayLayout.width)
                .frame(maxHeight: .infinity, alignment: .topLeading)
        } else {
            content.fixedSize(horizontal: true, vertical: false)
        }
    }
}
