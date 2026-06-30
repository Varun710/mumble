import AppKit
import Observation
import SwiftUI

extension Notification.Name {
    static let mumbleQuit = Notification.Name("mumbleQuit")
}

/// Persistent menu bar icon with pulse animation during dictation / transcription.
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private var observationTask: Task<Void, Never>?
    private weak var env: AppEnvironment?
    private var isPulsing = false
    private var lastMenuSnapshot: MenuSnapshot?

    var hasStatusItem: Bool { statusItem != nil }

    /// Whether the status item window is actually placed on the visible menu bar.
    var isIconOnScreen: Bool {
        guard let button = statusItem?.button else { return false }
        return MenuBarVisibilityChecker.statusItemIsOnScreen(button: button)
    }

    func install(env: AppEnvironment) {
        self.env = env
        guard statusItem == nil else { return }

        MenuBarRegistration.prepareForStatusItem()
        createStatusItem()
        startObserving(env: env)
        scheduleVisibilityRecovery()
    }

    /// Recreate the status item when macOS Tahoe parks it off-screen after allow-list changes.
    func recreateIfNeeded() {
        guard env != nil else { return }
        guard !isIconOnScreen else { return }
        AppLog.lifecycle.warning("menu bar icon not visible — recreating status item")
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        createStatusItem()
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "app.mumble.Mumble.statusItem"
        item.isVisible = true
        configureButton(item.button)
        item.menu = buildMenu()
        statusItem = item
        logStatusItemGeometry(item, label: "installed")

        if item.button == nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, let item = self.statusItem else { return }
                self.configureButton(item.button)
                self.logStatusItemGeometry(item, label: "button retry")
            }
        }
    }

    private func scheduleVisibilityRecovery() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            self?.recreateIfNeeded()
        }
    }

    private func logStatusItemGeometry(_ item: NSStatusItem, label: String) {
        guard let button = item.button, let window = button.window else {
            AppLog.lifecycle.warning("menu bar status item \(label, privacy: .public): no button/window")
            return
        }
        let frame = window.frame
        AppLog.lifecycle.info(
            "menu bar status item \(label, privacy: .public): visible=\(item.isVisible, privacy: .public) screen=\(window.screen != nil, privacy: .public) frame=\(NSStringFromRect(frame), privacy: .public) onScreen=\(self.isIconOnScreen, privacy: .public)"
        )
    }

    private func configureButton(_ button: NSStatusBarButton?) {
        guard let button else { return }
        let image = menuBarImage()
        image.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "Mumble"
    }

    func uninstall() {
        observationTask?.cancel()
        observationTask = nil
        stopPulse()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
    }

    private func startObserving(env: AppEnvironment) {
        observationTask?.cancel()
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                withObservationTracking {
                    _ = env.showsMenuBarActivity
                    _ = env.dictation.isActive
                    _ = env.overlay.model.phase
                    _ = env.recorder.isProcessing
                } onChange: { }

                let busy = env.showsMenuBarActivity
                if busy != self.isPulsing {
                    if busy { self.startPulse() } else { self.stopPulse() }
                }

                let snapshot = MenuSnapshot(env: env)
                if snapshot != self.lastMenuSnapshot {
                    self.lastMenuSnapshot = snapshot
                    self.updateMenu()
                }

                env.permissions.menuBar = self.isIconOnScreen ? .granted : .denied

                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func menuBarImage() -> NSImage {
        if let image = NSImage(named: "MenuBarSymbol") {
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        // Never return nil — an empty button is invisible on macOS 26.
        let fallback = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Mumble")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        fallback.size = NSSize(width: 18, height: 18)
        return fallback
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        rebuildMenu(menu)
        return menu
    }

    private func updateMenu() {
        guard let menu = statusItem?.menu else { return }
        rebuildMenu(menu)
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let dictationTitle: String
        if env?.dictation.isActive == true {
            dictationTitle = "Stop Dictation"
        } else if env?.overlay.model.phase == .transcribing || env?.recorder.isProcessing == true {
            dictationTitle = "Transcribing…"
        } else {
            dictationTitle = "Start Dictation"
        }

        let dictationItem = NSMenuItem(title: dictationTitle, action: #selector(toggleDictation), keyEquivalent: "")
        dictationItem.target = self
        dictationItem.isEnabled = env?.overlay.model.phase != .transcribing && env?.recorder.isProcessing != true
        menu.addItem(dictationItem)

        let hint = NSMenuItem(title: statusHint, action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        let openItem = NSMenuItem(title: "Open Mumble", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Mumble", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private var statusHint: String {
        guard let env else { return DictationShortcuts.holdHint }
        if env.dictation.isActive { return "Listening… release to transcribe" }
        if env.showsMenuBarActivity { return "Working…" }
        if env.dictation.isMonitoring { return DictationShortcuts.holdHint }
        if PermissionsService.menuBarPermissionRequired, env.permissions.menuBar != .granted {
            return "Enable Menu Bar in Settings ▸ Permissions"
        }
        return "Enable hotkey in Settings ▸ Permissions"
    }

    // MARK: - Pulse

    private func startPulse() {
        guard !isPulsing else { return }
        isPulsing = true
        pulseStep(to: 0.35)
    }

    private func stopPulse() {
        isPulsing = false
        statusItem?.button?.layer?.removeAllAnimations()
        statusItem?.button?.alphaValue = 1
    }

    private func pulseStep(to alpha: CGFloat) {
        guard isPulsing, let button = statusItem?.button else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.55
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            button.animator().alphaValue = alpha
        } completionHandler: { [weak self] in
            guard let self, self.isPulsing else { return }
            self.pulseStep(to: alpha < 1 ? 1.0 : 0.35)
        }
    }

    // MARK: - Actions

    @objc private func toggleDictation() {
        env?.dictation.toggle()
    }

    @objc private func openMainWindow() {
        MenuBarActions.openMainWindow()
    }

    @objc private func openSettings() {
        MenuBarActions.openSettings()
    }

    @objc private func quit() {
        NotificationCenter.default.post(name: .mumbleQuit, object: nil)
        env?.shutdown()
        NSApp.terminate(nil)
    }
}

enum MenuBarActions {
    static func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
        ActivationPolicyController.recompute()
    }

    static func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        ActivationPolicyController.recompute()
    }
}

private struct MenuSnapshot: Equatable {
    let dictationActive: Bool
    let overlayPhase: OverlayModel.Phase
    let recorderProcessing: Bool
    let statusHint: String

    init(env: AppEnvironment) {
        dictationActive = env.dictation.isActive
        overlayPhase = env.overlay.model.phase
        recorderProcessing = env.recorder.isProcessing
        if env.dictation.isActive {
            statusHint = "listening"
        } else if env.showsMenuBarActivity {
            statusHint = "working"
        } else if env.dictation.isMonitoring {
            statusHint = "monitoring"
        } else {
            statusHint = "disabled"
        }
    }
}
