import SwiftUI

/// First-run setup: welcome -> permissions -> model download.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    let onFinish: () -> Void

    @State private var step = 0
    private let steps = ["Welcome", "Permissions", "Models"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.separator(for: colorScheme))
            ScrollView {
                content
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().overlay(Theme.separator(for: colorScheme))
            footer
        }
        .frame(width: 580, height: 600)
        .background {
            ZStack {
                AmbientBackground()
            }
        }
        .foregroundStyle(Theme.textPrimary(for: colorScheme))
        .onAppear { env.permissions.refresh(); env.modelManager.refreshAvailability() }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image("Wordmark").resizable().scaledToFit().frame(height: 44)
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Theme.accent : Theme.textTertiary.opacity(0.3))
                        .frame(width: i == step ? 22 : 8, height: 6)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeStep
        case 1: permissionsStep
        default: modelsStep
        }
    }

    // MARK: Welcome

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Local-first voice to text")
                .font(.system(size: 22, weight: .bold))
            Text("Mumble transcribes your speech entirely on your Mac with WhisperKit. No account, no cloud — your audio never leaves your device.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary(for: colorScheme))

            VStack(alignment: .leading, spacing: 12) {
                feature("option", "Hold Right Option (⌥) to dictate", "Speak over any app; release to paste cleaned text at your cursor.")
                feature("waveform", "Record & transcribe", "Capture meetings or notes and get a searchable, timestamped transcript.")
                feature("lock.shield", "Private by design", "Everything is processed and stored locally.")
            }
            .padding(.top, 4)
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grant permissions")
                .font(.system(size: 20, weight: .bold))
            Text("Mumble needs these to record and to paste into other apps. You can change them later in Settings.")
                .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)

            permissionRow("Microphone", "Record your voice", env.permissions.microphone,
                          request: { Task { await env.permissions.requestMicrophone() } },
                          open: { env.permissions.openMicrophoneSettings() })
            permissionRow("Input Monitoring", "Detect the Right Option hotkey", env.permissions.inputMonitoring,
                          request: { env.permissions.requestInputMonitoring() },
                          open: { env.permissions.openInputMonitoringSettings() })
            permissionRow("Accessibility", "Paste text into other apps", env.permissions.accessibility,
                          request: { env.permissions.requestAccessibility(prompt: true) },
                          open: { env.permissions.openAccessibilitySettings() })

            Button("Refresh status") {
                env.permissions.refresh()
                env.dictation.startMonitoring()
            }
            .controlSize(.small)
            .padding(.top, 2)
        }
    }

    private func permissionRow(_ title: String, _ detail: String, _ state: PermissionState, request: @escaping () -> Void, open: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: state == .granted ? "checkmark.shield.fill" : "shield")
                .font(.system(size: 16))
                .foregroundStyle(state == .granted ? Theme.success : Theme.textTertiary(for: colorScheme))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textSecondary(for: colorScheme))
            }
            Spacer()
            switch state {
            case .granted: Text("Granted").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.success)
            case .notDetermined: Button("Grant", action: request).controlSize(.small).tint(Theme.accent)
            case .denied: Button("Open Settings", action: open).controlSize(.small)
            }
        }
        .contentCard(padding: 14, cornerRadius: Theme.cornerRadius)
    }

    // MARK: Models

    private var modelsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose a model")
                .font(.system(size: 20, weight: .bold))
            Text("Download at least one speech model to start. Base is fast and small; Large v3 Turbo is the most accurate on Apple Silicon. You can download more than one.")
                .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)

            ForEach(ModelManager.catalog) { model in
                modelRow(model)
            }
        }
    }

    private func modelRow(_ model: ModelInfo) -> some View {
        let state = env.modelManager.state(for: model.name)
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
                Text("\(model.detail)  ·  \(model.approxSize)")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            switch state {
            case .downloading(let p):
                VStack(spacing: 3) {
                    ProgressView(value: p).frame(width: 90).tint(Theme.accent)
                    Text("\(Int(p * 100))%").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                }
            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.success)
            case .failed:
                Button("Retry") { env.modelManager.download(model.name) }.controlSize(.small)
            case .notDownloaded:
                Button("Download") { env.modelManager.download(model.name) }.controlSize(.small).tint(Theme.accent)
            }
        }
        .contentCard(padding: 14, cornerRadius: Theme.cornerRadius)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary(for: colorScheme))
            }
            Spacer()
            if step < steps.count - 1 {
                Button("Continue") { withAnimation { step += 1 } }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
            } else {
                Button("Start using Mumble") { finish() }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                    .disabled(!env.modelManager.hasAnyDownloadedModel)
            }
        }
        .padding(20)
    }

    private func finish() {
        // Make sure the active model is one that's actually downloaded.
        if !env.modelManager.isReady(env.settings.modelName),
           let ready = ModelManager.catalog.first(where: { env.modelManager.isReady($0.name) }) {
            env.settings.modelName = ready.name
        }
        onFinish()
    }
}
