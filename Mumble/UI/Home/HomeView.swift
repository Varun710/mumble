import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]
    @State private var micPulse = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                modelSelectorSection
                header
                hero
                recentGrid
            }
            .padding(28)
        }
    }

    private var modelSelectorSection: some View {
        VStack(alignment: .trailing, spacing: 10) {
            topUtilityBar
            if !env.modelManager.isReady(env.settings.modelName) {
                ModelNotDownloadedNote(modelName: env.settings.modelName)
                    .frame(maxWidth: 360, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var topUtilityBar: some View {
        HStack(spacing: 10) {
            Spacer()
            BelowDropdown(minWidth: 210) {
                Text("Model")
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                Text(env.modelManager.displayName(for: env.settings.modelName))
                    .foregroundStyle(env.modelManager.isReady(env.settings.modelName) ? Theme.textPrimary(for: colorScheme) : Theme.recording)
                    .lineLimit(1)
            } content: { dismiss in
                ForEach(ModelManager.catalog) { model in
                    let state = env.modelManager.state(for: model.name)
                    Button {
                        selectModel(model)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Text(model.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(modelMenuStatus(for: state))
                                .font(.system(size: 11))
                                .foregroundStyle(modelMenuColor(for: state))
                            if model.name == env.settings.modelName {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(modelMenuColor(for: state))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(model.name == env.settings.modelName ? Theme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isModelMenuItemDisabled(state))
                }
            }
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentCard(padding: 0, cornerRadius: 11)
            .fixedSize()
        }
    }

    private func selectModel(_ model: ModelInfo) {
        env.settings.modelName = model.name
        if env.modelManager.isReady(model.name) {
            env.transcription.warmUp(model: model.name)
        }
    }

    private func modelMenuStatus(for state: ModelDownloadState) -> String {
        switch state {
        case .ready: return ""
        case .notDownloaded: return "Not downloaded"
        case .downloading(let progress): return "\(Int(progress * 100))%"
        case .failed: return "Download failed"
        }
    }

    private func modelMenuColor(for state: ModelDownloadState) -> Color {
        switch state {
        case .ready, .downloading: return Theme.textPrimary(for: colorScheme)
        case .notDownloaded, .failed: return Theme.recording
        }
    }

    private func isModelMenuItemDisabled(_ state: ModelDownloadState) -> Bool {
        if case .downloading = state { return true }
        return false
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 30, weight: .bold))
            Text("Speak naturally. Mumble transcribes and cleans it up locally.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
        }
    }

    private var hero: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Push-to-talk dictation")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.selection, in: Capsule())
                Text("Hold \(DictationShortcuts.holdLabel) anywhere to dictate")
                    .font(.system(size: 17, weight: .semibold))
                Text("Release to paste clean text into the active app.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                Button(env.recorder.isRecording ? "Stop recording" : "Start a recording") { env.recorder.toggle() }
                    .buttonStyle(.borderedProminent)
                    .tint(env.recorder.isRecording ? Theme.recording : Theme.accent)
            }
            Spacer()
            ZStack {
                if env.recorder.isRecording {
                    Circle()
                        .stroke(Theme.recording.opacity(0.35), lineWidth: 2)
                        .frame(width: 68, height: 68)
                        .scaleEffect(micPulse ? 1.85 : 1.0)
                        .opacity(micPulse ? 0 : 0.85)
                        .animation(.easeOut(duration: 1.15).repeatForever(autoreverses: false), value: micPulse)
                }
                Circle()
                    .stroke((env.recorder.isRecording ? Theme.recording : Theme.accent).opacity(0.16), lineWidth: 1)
                    .frame(width: 116, height: 116)
                Circle()
                    .stroke((env.recorder.isRecording ? Theme.recording : Theme.accent).opacity(0.25), lineWidth: 1)
                    .frame(width: 92, height: 92)
                Circle()
                    .fill((env.recorder.isRecording ? Theme.recording : Theme.accent).opacity(0.12))
                    .frame(width: 68, height: 68)
                Image(systemName: "mic.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(env.recorder.isRecording ? AnyShapeStyle(Theme.recording) : AnyShapeStyle(Theme.accentGradient))
                    .padding(23)
                    .background(Theme.cardBackground(for: colorScheme), in: Circle())
                    .overlay(Circle().strokeBorder((env.recorder.isRecording ? Theme.recording : Theme.accent).opacity(0.28), lineWidth: 1))
                    .scaleEffect(env.recorder.isRecording && micPulse ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: micPulse)
            }
        }
        .frame(minHeight: 132)
        .contentCard(padding: 24, cornerRadius: 20)
        .onAppear { micPulse = env.recorder.isRecording }
        .onChange(of: env.recorder.isRecording) { _, isRecording in
            micPulse = isRecording
        }
    }

    private var recentGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent recordings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("See all") { selection = .recordings }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
            }
            if recordings.isEmpty {
                emptyRecent
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    ForEach(recordings.prefix(6)) { recording in
                        RecordingCard(recording: recording) { selection = .recording(recording.id) }
                    }
                }
            }
        }
    }

    private var emptyRecent: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(Theme.accent)
            Text("No recordings yet")
                .font(.system(size: 14, weight: .semibold))
            Text("Start a recording or hold \(DictationShortcuts.holdLabel) to create your first transcript.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
            Button("Start recording") { env.recorder.toggle() }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .contentCard(cornerRadius: 18)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

struct RecordingCard: View {
    let recording: Recording
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recording.source == "dictation" ? "Dictation" : "Recording")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.selection, in: Capsule())
                    Spacer()
                    Text(durationLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                }
                Text(recording.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary(for: colorScheme))
                    .lineLimit(1)
                Text(recording.transcript.isEmpty ? "No transcript" : recording.transcript)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentCard()
            .background(isHovering ? Theme.hover(for: colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.16), value: isHovering)
    }

    private var durationLabel: String {
        String(format: "%01d:%02d", Int(recording.duration) / 60, Int(recording.duration) % 60)
    }
}
