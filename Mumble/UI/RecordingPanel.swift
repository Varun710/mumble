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
}
