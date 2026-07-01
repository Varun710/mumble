import SwiftUI

private enum SettingsMetrics {
    static let chromePadding: CGFloat = 20
    static let contentPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let rowMinHeight: CGFloat = 30
}

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var tab: Tab = .general

    enum Tab: String, CaseIterable, Identifiable {
        case general = "General"
        case recording = "Recording"
        case dictation = "Dictation"
        case intelligence = "Intelligence"
        case models = "Models"
        case dictionary = "Dictionary"
        case permissions = "Permissions"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .general: return "paintbrush"
            case .recording: return "waveform"
            case .dictation: return "text.cursor"
            case .intelligence: return "brain"
            case .models: return "cpu"
            case .dictionary: return "character.book.closed"
            case .permissions: return "lock.shield"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Settings").font(.system(size: 18, weight: .semibold))
                    Spacer()
                }

                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Label(t.rawValue, systemImage: t.icon)
                            .font(.system(size: 13, weight: .medium))
                            .tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .font(.system(size: 13, weight: .medium))
                .controlSize(.regular)
                .labelsHidden()
            }
            .padding(SettingsMetrics.chromePadding)

            Divider().overlay(Theme.separator(for: colorScheme))

            ScrollView {
                Group {
                    switch tab {
                    case .general: GeneralSettingsSection()
                    case .recording: RecordingSettingsSection()
                    case .dictation: DictationSettingsSection()
                    case .intelligence: IntelligenceSettingsSection()
                    case .models: ModelsSettingsSection()
                    case .dictionary: DictionarySettingsSection()
                    case .permissions: PermissionsSettingsSection()
                    }
                }
                .padding(SettingsMetrics.contentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(Theme.textPrimary(for: colorScheme))
    }
}

// MARK: - General

private struct GeneralSettingsSection: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            SettingsGroup("Appearance") {
                LabeledRow("Theme") {
                    BelowDropdownPicker(selection: $settings.appearance, values: AppearanceMode.allCases, minWidth: 126) { mode in
                        Text(mode.label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textPrimary(for: colorScheme))
                    } rowContent: { mode, _ in
                        Text(mode.label)
                    }
                }
                SettingsFootnote("Choose System to follow your Mac's light or dark mode.")
            }
        }
    }
}

// MARK: - Recording

private struct RecordingSettingsSection: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            SettingsGroup("Transcription") {
                LabeledRow("Language") {
                    BelowDropdownPicker(selection: $settings.language, values: LanguageOption.all.map(\.code), minWidth: 168) { code in
                        Text(LanguageOption.name(for: code))
                            .font(.system(size: 12, weight: .medium))
                    } rowContent: { code, _ in
                        Text(LanguageOption.name(for: code))
                    }
                }
                LabeledRow("Model") {
                    BelowDropdownPicker(selection: $settings.modelName, values: ModelManager.catalog.map(\.name), minWidth: 210) { name in
                        Text(env.modelManager.displayName(for: name))
                            .font(.system(size: 12, weight: .medium))
                    } rowContent: { name, _ in
                        HStack {
                            Text(env.modelManager.displayName(for: name))
                            if !env.modelManager.isReady(name) {
                                Text("Not downloaded")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.recording)
                            }
                        }
                    }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
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
                            .foregroundStyle(Theme.textTertiary(for: colorScheme))
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
                        .foregroundStyle(Theme.textSecondary(for: colorScheme))
                    Spacer()
                    if !env.dictation.isMonitoring {
                        Button("Enable") { env.dictation.startMonitoring(); env.permissions.refresh() }
                            .controlSize(.small)
                    }
                }
                SettingsFootnote("You can also start/stop hands-free from the menu bar icon.")
            }

            SettingsGroup("Output") {
                ToggleRow("Paste into active app", isOn: $settings.pasteIntoActiveApp)
                ToggleRow("Copy to clipboard", isOn: $settings.copyToClipboard)
                ToggleRow("Restore clipboard after paste", isOn: $settings.restoreClipboard)
            }

            SettingsFootnote("Pasting into other apps requires Accessibility permission (see the Permissions tab) and only works in a non-sandboxed build.")
        }
    }
}

// MARK: - Models

private struct ModelsSettingsSection: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            Text("Download a model to use Mumble. They are cached locally; larger models are more accurate but slower. You can download several at once.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))

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
                Text(model.detail).font(.system(size: 11)).foregroundStyle(Theme.textSecondary(for: colorScheme))
                Text(model.approxSize).font(.system(size: 10)).foregroundStyle(Theme.textTertiary(for: colorScheme))
            }
            Spacer()
            stateView(model: model, state: state, isCurrent: isCurrent)
        }
        .contentCard(padding: 16, cornerRadius: Theme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .strokeBorder(isCurrent ? Theme.accent.opacity(0.5) : Theme.separator(for: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func stateView(model: ModelInfo, state: ModelDownloadState, isCurrent: Bool) -> some View {
        switch state {
        case .downloading(let p):
            VStack(spacing: 4) {
                ProgressView(value: p).frame(width: 90).tint(Theme.accent)
                Text("\(Int(p * 100))%").font(.system(size: 10)).foregroundStyle(Theme.textTertiary(for: colorScheme))
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

// MARK: - Intelligence

private struct IntelligenceSettingsSection: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var newTrigger = ""
    @State private var newExpansion = ""

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            SettingsGroup("Interpreter") {
                HStack(spacing: 8) {
                    Image(systemName: InterpreterBackendFactory.isAnyAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(InterpreterBackendFactory.isAnyAvailable ? Theme.success : Theme.recording)
                    Text(interpreterStatusLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary(for: colorScheme))
                }
                ToggleRow("Smart dictation (corrections & commands)", isOn: $settings.interpreterEnabled)
                    .disabled(!InterpreterBackendFactory.isAnyAvailable)
                SettingsFootnote("Resolves self-corrections, voice commands, and style-aware cleanup on-device. Falls back to deterministic cleanup on failure.")
            }

            SettingsGroup("Style") {
                ToggleRow("Auto style by app", isOn: $settings.autoStyleByApp)
                LabeledRow("Manual preset") {
                    BelowDropdownPicker(
                        selection: $settings.stylePreset,
                        values: StylePreset.allCases,
                        minWidth: 140
                    ) { preset in
                        Text(preset.label).font(.system(size: 12, weight: .medium))
                    } rowContent: { preset, _ in
                        Text(preset.label)
                    }
                }
                .disabled(settings.autoStyleByApp)
            }

            SettingsGroup("Add snippet") {
                Text("Speak a trigger phrase to insert expanded text before interpretation.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                HStack(spacing: 8) {
                    TextField("Trigger phrase…", text: $newTrigger)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    TextField("Expansion…", text: $newExpansion)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    Button("Add") { addSnippet() }
                        .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            SettingsGroup("Snippets") {
                if settings.snippets.isEmpty {
                    Text("No snippets yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                } else {
                    VStack(spacing: 8) {
                        ForEach(settings.snippets) { snippet in
                            HStack {
                                Text(snippet.trigger).font(.system(size: 12, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                                Text(snippet.expansion)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                                    .lineLimit(2)
                                Spacer()
                                Button { remove(snippet) } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                            }
                        }
                    }
                }
            }
        }
    }

    private var interpreterStatusLabel: String {
        if InterpreterBackendFactory.isAnyAvailable {
            return "On-device interpreter available (Apple Intelligence or MLX)."
        }
        return "Interpreter unavailable. Enable Apple Intelligence on macOS 26+ or download an MLX model."
    }

    private func addSnippet() {
        let trigger = newTrigger.trimmingCharacters(in: .whitespaces)
        let expansion = newExpansion.trimmingCharacters(in: .whitespaces)
        guard !trigger.isEmpty else { return }
        env.settings.snippets.append(Snippet(trigger: trigger, expansion: expansion))
        newTrigger = ""
        newExpansion = ""
    }

    private func remove(_ snippet: Snippet) {
        env.settings.snippets.removeAll { $0.id == snippet.id }
    }
}

// MARK: - Dictionary

private struct DictionarySettingsSection: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var newFrom = ""
    @State private var newTo = ""

    var body: some View {
        @Bindable var settings = env.settings
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            SettingsGroup("Add replacement") {
                Text("Replace spoken words with preferred spellings. Matching is case-insensitive.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))

                HStack(spacing: 8) {
                    TextField("Heard…", text: $newFrom)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                    TextField("Replace with…", text: $newTo)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    Button("Add") { addEntry() }
                        .disabled(newFrom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            SettingsGroup("Entries") {
                if settings.dictionaryEntries.isEmpty {
                    Text("No entries yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 8) {
                        ForEach(settings.dictionaryEntries) { entry in
                            HStack {
                                Text(entry.from).font(.system(size: 12, weight: .medium))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                                Text(entry.to)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
                                Spacer()
                                Button { remove(entry) } label: { Image(systemName: "xmark.circle.fill") }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Theme.textTertiary(for: colorScheme))
                            }
                            .frame(minHeight: SettingsMetrics.rowMinHeight)
                        }
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
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
            SettingsGroup("System permissions") {
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
                if PermissionsService.menuBarPermissionRequired {
                    permissionRow(
                        title: "Menu Bar",
                        detail: "Required to show the Mumble icon in the menu bar (macOS Tahoe). If Mumble is missing from System Settings → Menu Bar, quit and reopen the app.",
                        state: env.permissions.menuBar,
                        action: { env.permissions.requestMenuBar() },
                        openSettings: { env.permissions.openMenuBarSettings() }
                    )
                }
            }
            HStack(spacing: 12) {
                Button("Refresh status") {
                    env.permissions.refresh()
                    env.dictation.startMonitoring()
                }
                    .controlSize(.small)
                Button("Run setup again") { env.showOnboarding = true }
                    .controlSize(.small)
            }
            .foregroundStyle(Theme.textSecondary(for: colorScheme))
        }
        .onAppear { env.permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            env.permissions.refresh()
            env.dictation.startMonitoring()
        }
    }

    private func permissionRow(title: String, detail: String, state: PermissionState, action: @escaping () -> Void, openSettings: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(state))
                .font(.system(size: 16))
                .foregroundStyle(color(state))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textSecondary(for: colorScheme))
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
        .frame(minHeight: SettingsMetrics.rowMinHeight)
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
        case .notDetermined: return Theme.textTertiary(for: colorScheme)
        }
    }
}

// MARK: - Reusable

private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary(for: colorScheme))
            VStack(spacing: 12) { content }
                .contentCard(padding: 16, cornerRadius: Theme.cornerRadius)
        }
    }
}

private struct LabeledRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            content
        }
        .frame(minHeight: SettingsMetrics.rowMinHeight)
    }
}

struct ModelNotDownloadedNote: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
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
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary(for: colorScheme))
                Spacer()
                Text("\(Int(p * 100))%")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textSecondary(for: colorScheme))
            case .failed:
                Text("Download failed.")
                    .font(.system(size: 11)).foregroundStyle(Theme.recording)
                Spacer()
                Button("Retry") { env.modelManager.download(modelName) }.controlSize(.small)
            default:
                Text("This model isn’t downloaded yet.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary(for: colorScheme))
                Spacer()
                Button("Download") { env.modelManager.download(modelName) }
                    .controlSize(.small).tint(Theme.accent)
            }
        }
        .padding(10)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SettingsFootnote: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary(for: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.textPrimary(for: colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small).tint(Theme.accent)
        }
        .frame(minHeight: SettingsMetrics.rowMinHeight)
    }
}
