import SwiftUI

/// Home-screen banner shown while speech recognition is actively running.
struct ASRHomeStatusBanner: View {
    let status: ASRHomeStatus

    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Theme.recording.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 34, height: 34)
                    .scaleEffect(pulse ? 1.3 : 1.0)
                    .opacity(pulse ? 0 : 0.8)
                    .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)

                Circle()
                    .fill(Theme.recording)
                    .frame(width: 34, height: 34)
                    .shadow(color: Theme.recording.opacity(0.35), radius: 8)

                statusIcon
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                Text(status.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("Live")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.recording)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.recording.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.recording.opacity(0.28), lineWidth: 1)
        )
        .onAppear { pulse = true }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .listening:
            Image(systemName: "mic.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        case .recording:
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        case .transcribing:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        }
    }
}
