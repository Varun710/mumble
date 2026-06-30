import SwiftUI

/// The large circular record button in the right-hand panel.
struct RecordOrb: View {
    let phase: RecorderViewModel.Phase
    let levels: [Float]
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.accent.opacity(0.5), radius: phase == .recording ? 24 : 14)
                        .scaleEffect(phase == .recording && pulse ? 1.06 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

                    if phase == .recording {
                        ringPulse
                    }

                    icon
                }
            }
            .buttonStyle(.plain)
            .onAppear {
                pulse = (phase == .recording)
            }
            .onChange(of: phase) { _, newValue in
                pulse = (newValue == .recording)
            }

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))

            Text(phase == .recording ? "Click to stop" : "⌘N")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary(for: colorScheme))
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch phase {
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: 30, weight: .medium)).foregroundStyle(.white)
        case .recording:
            RoundedRectangle(cornerRadius: 5).fill(.white).frame(width: 26, height: 26)
        case .processing:
            ProgressView().controlSize(.large).tint(.white)
        }
    }

    private var ringPulse: some View {
        Circle()
            .stroke(Theme.accent.opacity(0.4), lineWidth: 2)
            .frame(width: 96, height: 96)
            .scaleEffect(pulse ? 1.4 : 1.0)
            .opacity(pulse ? 0 : 0.8)
            .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: pulse)
    }

    private var statusText: String {
        switch phase {
        case .idle: return "Click to start recording"
        case .recording: return "Recording…"
        case .processing: return "Transcribing…"
        }
    }
}
