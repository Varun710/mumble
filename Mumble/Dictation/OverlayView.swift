import SwiftUI

/// The small recording capsule shown during push-to-talk dictation.
/// Uses the Mumble purple color scheme with subtle animation.
struct OverlayView: View {
    @Bindable var model: OverlayModel
    @State private var appear = false

    var body: some View {
        HStack(spacing: 12) {
            indicator
            content
            Spacer(minLength: 0)
            if model.phase == .listening {
                Text(timeString(model.elapsed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(capsule)
        .padding(8)
        .scaleEffect(appear ? 1 : 0.85)
        .opacity(appear ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { appear = true } }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.phase)
    }

    private var capsule: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(hex: 0x14121C))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.55), Theme.accentSoft.opacity(0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.accent.opacity(model.phase == .listening ? 0.35 : 0.18), radius: 18, y: 6)
    }

    @ViewBuilder
    private var indicator: some View {
        switch model.phase {
        case .listening:
            PulseOrb()
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(Theme.accent)
                .frame(width: 26, height: 26)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Theme.success)
                .transition(.scale.combined(with: .opacity))
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .listening:
            LiveWaveform(levels: model.levels)
                .frame(width: 132, height: 30)
        case .transcribing:
            Text("Transcribing…")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        case .done:
            Text("Pasted")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
        case .error:
            Text(model.message.isEmpty ? "Something went wrong" : model.message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

/// Animated pulsing purple orb shown while listening.
private struct PulseOrb: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.5), lineWidth: 2)
                .frame(width: 26, height: 26)
                .scaleEffect(animate ? 1.7 : 1.0)
                .opacity(animate ? 0 : 0.7)

            Circle()
                .fill(Theme.accentGradient)
                .frame(width: 26, height: 26)
                .shadow(color: Theme.accent.opacity(0.7), radius: animate ? 8 : 3)

            Image(systemName: "mic.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}
