import SwiftUI

/// The small recording capsule shown during push-to-talk dictation.
/// Floats above all apps with liquid glass styling.
struct OverlayView: View {
    @Bindable var model: OverlayModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var appear = false

    private var isActive: Bool {
        model.phase == .listening || model.phase == .transcribing
    }

    var body: some View {
        Group {
            switch model.phase {
            case .listening:
                listeningCapsule
            case .transcribing, .done, .error:
                compactCapsule
            }
        }
        .scaleEffect(appear ? 1 : 0.9)
        .opacity(appear ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) { appear = true }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.phase)
    }

    // MARK: - Listening layout

    private var listeningCapsule: some View {
        HStack(spacing: 12) {
            PulseOrb(size: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text("Listening")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))

                LiveWaveform(levels: model.levels, amplified: true)
                    .frame(height: 36)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(timeString(model.elapsed))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary(for: colorScheme))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(OverlayCapsuleChrome(isActive: true))
    }

    // MARK: - Other phases

    private var compactCapsule: some View {
        HStack(spacing: 12) {
            phaseIndicator
            phaseContent
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .modifier(OverlayCapsuleChrome(isActive: isActive))
    }

    @ViewBuilder
    private var phaseIndicator: some View {
        switch model.phase {
        case .transcribing:
            ZStack {
                Circle()
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 2)
                    .frame(width: 32, height: 32)
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.accent)
            }
            .frame(width: 32, height: 32)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.success)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .transcribing:
            HStack(spacing: 8) {
                Text("Transcribing…")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                if !model.modelName.isEmpty {
                    Text(model.modelName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.accent.opacity(0.14), in: Capsule())
                }
            }
        case .done:
            HStack(spacing: 6) {
                Text("Pasted")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                localBadge
            }
        case .error:
            Text(model.message.isEmpty ? "Something went wrong" : model.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        default:
            EmptyView()
        }
    }

    private var localBadge: some View {
        Text("Local")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accent.opacity(0.14), in: Capsule())
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

/// Single glass capsule chrome — no stacked rectangle behind the rounded shape.
private struct OverlayCapsuleChrome: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .glassPanel(cornerRadius: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Theme.accent.opacity(isActive ? 0.6 : 0.35),
                                Theme.accentSoft.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.accent.opacity(isActive ? 0.32 : 0.12), radius: isActive ? 18 : 10, y: 6)
    }
}

/// Animated pulsing purple orb shown while listening.
private struct PulseOrb: View {
    var size: CGFloat = 38
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.45), lineWidth: 2)
                .frame(width: size, height: size)
                .scaleEffect(animate ? 1.75 : 1.0)
                .opacity(animate ? 0 : 0.75)

            Circle()
                .fill(Theme.accentGradient)
                .frame(width: size, height: size)
                .shadow(color: Theme.accent.opacity(0.75), radius: animate ? 12 : 5)

            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.05).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}
