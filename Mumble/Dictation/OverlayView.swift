import SwiftUI

/// The small recording capsule shown during push-to-talk dictation.
struct OverlayView: View {
    @Bindable var model: OverlayModel

    var body: some View {
        HStack(spacing: 12) {
            indicator
            content
            Spacer(minLength: 0)
            timer
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0x16161D))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        )
        .padding(6)
    }

    @ViewBuilder
    private var indicator: some View {
        switch model.phase {
        case .listening:
            Circle()
                .fill(Theme.recording)
                .frame(width: 12, height: 12)
                .shadow(color: Theme.recording.opacity(0.7), radius: 5)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(Theme.accent)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.recording)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .listening:
            LiveWaveform(levels: model.levels, color: Theme.accent)
                .frame(width: 130, height: 28)
        case .transcribing:
            Text("Transcribing…").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textSecondary)
        case .done:
            Text("Pasted").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.textSecondary)
        case .error:
            Text(model.message.isEmpty ? "Something went wrong" : model.message)
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary).lineLimit(2)
        }
    }

    private var timer: some View {
        Text(model.phase == .listening ? timeString(model.elapsed) : "")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.textTertiary)
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%01d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
