import SwiftUI

/// Right-hand panel: record orb, quick recording settings, and AI commands.
struct RecordingPanel: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var settings = env.settings
        ScrollView {
            VStack(spacing: 18) {
                orbCard
                recordingSettings(settings)
                AICommandsPanel()
            }
            .padding(16)
        }
    }

    private var orbCard: some View {
        VStack {
            RecordOrb(
                phase: env.recorder.phase,
                levels: env.recorder.levels,
                action: { env.recorder.toggle() }
            )
            .padding(.vertical, 18)

            if let error = env.recorder.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.recording)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .contentCard(padding: 0, cornerRadius: 16)
    }

    private func recordingSettings(_ settings: SettingsStore) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recording Settings")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))

            settingRow("Language") {
                BelowDropdownPicker(
                    selection: Binding(get: { settings.language }, set: { settings.language = $0 }),
                    values: LanguageOption.all.map(\.code),
                    minWidth: 168
                ) { code in
                    Text(LanguageOption.name(for: code))
                        .font(.system(size: 12, weight: .medium))
                } rowContent: { code, _ in
                    Text(LanguageOption.name(for: code))
                }
            }

            settingRow("Model") {
                BelowDropdownPicker(
                    selection: Binding(get: { settings.modelName }, set: { settings.modelName = $0 }),
                    values: ModelManager.catalog.map(\.name),
                    minWidth: 210
                ) { name in
                    Text(env.modelManager.displayName(for: name))
                        .font(.system(size: 12, weight: .medium))
                } rowContent: { name, _ in
                    let state = env.modelManager.state(for: name)
                    HStack {
                        Text(env.modelManager.displayName(for: name))
                        Text(modelStatus(for: state))
                            .font(.system(size: 11))
                            .foregroundStyle(modelStatusColor(for: state))
                    }
                }
            }

            if !env.modelManager.isReady(settings.modelName) {
                ModelNotDownloadedNote(modelName: settings.modelName)
            }

            settingRow("Device") {
                Text("Auto (Apple Silicon)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
            }

            HStack {
                Text("Auto punctuation")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                Spacer()
                Toggle("", isOn: Binding(get: { settings.autoPunctuation }, set: { settings.autoPunctuation = $0 }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(Theme.accent)
            }

            Button(action: { selection = .settings }) {
                HStack {
                    Text("More settings")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .contentCard(cornerRadius: 16)
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))
            Spacer()
            content()
        }
    }

    private func modelStatus(for state: ModelDownloadState) -> String {
        switch state {
        case .ready: return ""
        case .notDownloaded: return "Not downloaded"
        case .downloading(let progress): return "\(Int(progress * 100))%"
        case .failed: return "Download failed"
        }
    }

    private func modelStatusColor(for state: ModelDownloadState) -> Color {
        switch state {
        case .ready, .downloading: return Theme.textPrimary(for: colorScheme)
        case .notDownloaded, .failed: return Theme.recording
        }
    }
}
