import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tab: Tab = .recording

    enum Tab: String, CaseIterable, Identifiable {
        case recording = "Recording"
        case dictation = "Dictation"
        case models = "Models"
        case dictionary = "Dictionary"
        case permissions = "Permissions"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .recording: return "waveform"
            case .dictation: return "text.cursor"
            case .models: return "cpu"
            case .dictionary: return "character.book.closed"
            case .permissions: return "lock.shield"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(20)

            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)

            Divider().overlay(Theme.separator).padding(.top, 16)

            ScrollView {
                Group {
                    switch tab {
                    case .recording: RecordingSettingsSection()
                    case .dictation: DictationSettingsSection()
                    case .models: ModelsSettingsSection()
                    case .dictionary: DictionarySettingsSection()
                    case .permissions: PermissionsSettingsSection()
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Theme.windowBackground)
        .foregroundStyle(Theme.textPrimary)
    }
}

// MARK: - Recording

private struct RecordingSettingsSection: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup("Transcription") {
                LabeledRow("Language") {
                    Picker("", selection: $settings.language) {
                        ForEach(LanguageOption.all) { Text($0.name).tag($0.code) }
                    }.labelsHidden().fixedSize()
                }
                LabeledRow("Model") {
                    Picker("", selection: $settings.modelName) {
                        ForEach(ModelManager.catalog) { model in
                            Text(env.modelManager.isReady(model.name) ? model.displayName : "\(model.displayName) (not downloaded)")
                                .tag(model.name)
                        }
                    }.labelsHidden().fixedSize()
                }
                if !env.modelManager.isReady(settings.modelName) {
                    ModelNotDownloadedNote(modelName: settings.modelName)
                }
                ToggleRow("Auto punctuation", isOn: $settings.autoPunctuation)
            }

            SettingsGroup("Cleanup") {
                ToggleRow("Remove filler words (um, uh, er)", isOn: $settings.removeFillers)
                ToggleRow("Collapse repeated words", isOn: $settings.collapseRepeats)
                ToggleRow("Normalize spacing & punctuation", isOn: $settings.normalizeSpacing)
                ToggleRow("Apply custom dictionary", isOn: $settings.applyDictionary)
            }
        }
    }
}

// MARK: - Dictation

private struct DictationSettingsSection: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup("Push-to-talk") {
                HStack(spacing: 10) {
                    Image(systemName: "option")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold the Right Option (⌥) key to dictate")
                            .font(.system(size: 13, weight: .medium))
                        Text("Works on top of any app. Release to transcribe and paste.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(env.dictation.isMonitoring ? Theme.success : Theme.recording)
                        .frame(width: 7, height: 7)
                    Text(env.dictation.isMonitoring
                         ? "Hotkey active"
                         : "Hotkey inactive — grant Input Monitoring in the Permissions tab")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    if !env.dictation.isMonitoring {
                        Button("Enable") { env.dictation.startMonitoring(); env.permissions.refresh() }
                            .controlSize(.small)
                    }
                }
                Text("You can also start/stop hands-free from the menu bar icon.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }

            SettingsGroup("Output") {
                ToggleRow("Paste into active app", isOn: $settings.pasteIntoActiveApp)
                ToggleRow("Copy to clipboard", isOn: $settings.copyToClipboard)
                ToggleRow("Restore clipboard after paste", isOn: $settings.restoreClipboard)
            }

            Text("Pasting into other apps requires Accessibility permission (see the Permissions tab) and only works in a non-sandboxed build.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}

// MARK: - Models

private struct ModelsSettingsSection: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Download a model to use Mumble. They are cached locally; larger models are more accurate but slower. You can download several at once.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            ForEach(ModelManager.catalog) { model in
                modelRow(model)
            }
        }
    }

    private func modelRow(_ model: ModelInfo) -> some View {
        let state = env.modelManager.state(for: model.name)
        let isCurrent = env.settings.modelName == model.name
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayName).font(.system(size: 13, weight: .semibold))
                    if model.recommended {
                        Text("Recommended").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.15), in: Capsule())
                    }
                }
                Text(model.detail).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                Text(model.approxSize).font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            stateView(model: model, state: state, isCurrent: isCurrent)
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isCurrent ? Theme.accent.opacity(0.5) : Theme.separator, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func stateView(model: ModelInfo, state: ModelDownloadState, isCurrent: Bool) -> some View {
        switch state {
        case .downloading(let p):
            VStack(spacing: 4) {
                ProgressView(value: p).frame(width: 90).tint(Theme.accent)
                Text("\(Int(p * 100))%").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            }
        case .ready:
            if isCurrent {
                Label("In use", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.success)
            } else {
                Button("Use") { env.settings.modelName = model.name; env.transcription.warmUp(model: model.name) }
                    .controlSize(.small)
            }
        case .failed(let message):
            VStack(alignment: .trailing, spacing: 2) {
                Button("Retry") { download(model) }.controlSize(.small)
                Text(message).font(.system(size: 9)).foregroundStyle(Theme.recording).lineLimit(1).frame(maxWidth: 120)
            }
        case .notDownloaded:
            Button("Download") { download(model) }
                .controlSize(.small)
                .tint(Theme.accent)
        }
    }

    private func download(_ model: ModelInfo) {
        env.modelManager.download(model.name)
    }
}

// MARK: - Dictionary

private struct DictionarySettingsSection: View {
    @Environment(AppEnvironment.self) private var env
    @State private var newFrom = ""
    @State private var newTo = ""

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: 14) {
            Text("Replace spoken words with preferred spellings (names, acronyms, technical terms). Matching is case-insensitive.")
                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)

            HStack(spacing: 8) {
                TextField("Heard…", text: $newFrom).textFieldStyle(.roundedBorder).frame(width: 160)
                Image(systemName: "arrow.right").foregroundStyle(Theme.textTertiary)
                TextField("Replace with…", text: $newTo).textFieldStyle(.roundedBorder).frame(width: 160)
                Button("Add") { addEntry() }
                    .disabled(newFrom.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if settings.dictionaryEntries.isEmpty {
                Text("No entries yet.").font(.system(size: 12)).foregroundStyle(Theme.textTertiary).padding(.top, 4)
            } else {
                VStack(spacing: 6) {
                    ForEach(settings.dictionaryEntries) { entry in
                        HStack {
                            Text(entry.from).font(.system(size: 12, weight: .medium))
                            Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(Theme.textTertiary)
                            Text(entry.to).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Button { remove(entry) } label: { Image(systemName: "xmark.circle.fill") }
                                .buttonStyle(.plain).foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func addEntry() {
        let from = newFrom.trimmingCharacters(in: .whitespaces)
        let to = newTo.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty else { return }
        env.settings.dictionaryEntries.append(DictionaryEntry(from: from, to: to))
        newFrom = ""; newTo = ""
    }

    private func remove(_ entry: DictionaryEntry) {
        env.settings.dictionaryEntries.removeAll { $0.id == entry.id }
    }
}

// MARK: - Permissions

private struct PermissionsSettingsSection: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            permissionRow(
                title: "Microphone",
                detail: "Required to record audio for transcription.",
                state: env.permissions.microphone,
                action: { Task { await env.permissions.requestMicrophone() } },
                openSettings: { env.permissions.openMicrophoneSettings() }
            )
            permissionRow(
                title: "Accessibility",
                detail: "Required to paste dictated text into other apps.",
                state: env.permissions.accessibility,
                action: { env.permissions.requestAccessibility(prompt: true) },
                openSettings: { env.permissions.openAccessibilitySettings() }
            )
            permissionRow(
                title: "Input Monitoring",
                detail: "Required for the global push-to-talk hotkey.",
                state: env.permissions.inputMonitoring,
                action: { env.permissions.requestInputMonitoring() },
                openSettings: { env.permissions.openInputMonitoringSettings() }
            )
            HStack {
                Button("Refresh status") { env.permissions.refresh(); env.dictation.startMonitoring() }
                    .controlSize(.small)
                Button("Run setup again") { env.showOnboarding = true }
                    .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .onAppear { env.permissions.refresh() }
    }

    private func permissionRow(title: String, detail: String, state: PermissionState, action: @escaping () -> Void, openSettings: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(state))
                .font(.system(size: 16))
                .foregroundStyle(color(state))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            switch state {
            case .granted:
                Text("Granted").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.success)
            case .notDetermined:
                Button("Request", action: action).controlSize(.small)
            case .denied:
                Button("Open Settings", action: openSettings).controlSize(.small)
            }
        }
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func icon(_ s: PermissionState) -> String {
        switch s {
        case .granted: return "checkmark.shield.fill"
        case .denied: return "xmark.shield.fill"
        case .notDetermined: return "questionmark.circle"
        }
    }

    private func color(_ s: PermissionState) -> Color {
        switch s {
        case .granted: return Theme.success
        case .denied: return Theme.recording
        case .notDetermined: return Theme.textTertiary
        }
    }
}

// MARK: - Reusable

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            VStack(spacing: 12) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct LabeledRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
            Spacer()
            content
        }
    }
}

struct ModelNotDownloadedNote: View {
    @Environment(AppEnvironment.self) private var env
    let modelName: String

    var body: some View {
        let state = env.modelManager.state(for: modelName)
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
            switch state {
            case .downloading(let p):
                Text("Downloading \(env.modelManager.displayName(for: modelName))…")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(p * 100))%")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary)
            case .failed:
                Text("Download failed.")
                    .font(.system(size: 11)).foregroundStyle(Theme.recording)
                Spacer()
                Button("Retry") { env.modelManager.download(modelName) }.controlSize(.small)
            default:
                Text("This model isn’t downloaded yet.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Download") { env.modelManager.download(modelName) }
                    .controlSize(.small).tint(Theme.accent)
            }
        }
        .padding(10)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }
    var body: some View {
        HStack {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.accent)
        }
    }
}
