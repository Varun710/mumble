import SwiftUI

/// Right-hand panel: record orb, quick recording settings, and AI commands.
struct RecordingPanel: View {
    @Binding var selection: SidebarItem
    @Environment(AppEnvironment.self) private var env

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
        .background(Theme.panelBackground)
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
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func recordingSettings(_ settings: SettingsStore) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recording Settings")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)

            settingRow("Language") {
                Picker("", selection: Binding(get: { settings.language }, set: { settings.language = $0 })) {
                    ForEach(LanguageOption.all) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            settingRow("Model") {
                Picker("", selection: Binding(get: { settings.modelName }, set: { settings.modelName = $0 })) {
                    ForEach(ModelManager.catalog) { model in
                        Text(model.displayName).tag(model.name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            if !env.modelManager.isReady(settings.modelName) {
                ModelNotDownloadedNote(modelName: settings.modelName)
            }

            settingRow("Device") {
                Text("Auto (Apple Silicon)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack {
                Text("Auto punctuation")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
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
                .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            content()
        }
    }
}
