import AppKit
import Foundation

extension Notification.Name {
    /// Posted when the AppKit layer needs SwiftUI to (re)create the main `WindowGroup` window.
    static let mumbleOpenMainWindow = Notification.Name("mumbleOpenMainWindow")
}

/// A pure snapshot of an `NSWindow` used so window-selection logic can be unit tested
/// without a live `NSApplication`.
struct WindowDescriptor: Sendable, Equatable {
    let isPanel: Bool
    let isVisible: Bool
    let canBecomeMain: Bool
    let hasMainIdentifier: Bool

    nonisolated init(isPanel: Bool, isVisible: Bool, canBecomeMain: Bool, hasMainIdentifier: Bool) {
        self.isPanel = isPanel
        self.isVisible = isVisible
        self.canBecomeMain = canBecomeMain
        self.hasMainIdentifier = hasMainIdentifier
    }
}

/// Pure activation-policy decisions, extracted so they can be tested without `NSApp`.
enum MainWindowPolicy {
    nonisolated static func desired(hasVisibleMainWindow: Bool) -> NSApplication.ActivationPolicy {
        hasVisibleMainWindow ? .regular : .accessory
    }

    /// A demotion to `.accessory` is only safe when no show sequence is running.
    /// While a show is in flight the target window may not be visible yet, so we must
    /// not let a stray `didBecomeKey` / `willClose` observer flip us back to accessory.
    nonisolated static func shouldAllowDemotion(showInProgress: Bool, hasVisibleMainWindow: Bool) -> Bool {
        if showInProgress { return false }
        return !hasVisibleMainWindow
    }
}

/// Pure main-window selection, extracted so it can be tested without `NSApp`.
enum MainWindowSelection {
    nonisolated static func isEligible(_ descriptor: WindowDescriptor) -> Bool {
        !descriptor.isPanel && descriptor.canBecomeMain
    }

    /// Chooses the best candidate index: any non-panel main-capable window, preferring
    /// ones that are already visible and carry the `main` scene identifier.
    nonisolated static func bestIndex(in windows: [WindowDescriptor]) -> Int? {
        let eligible = windows.enumerated().filter { isEligible($0.element) }
        guard !eligible.isEmpty else { return nil }
        return eligible.max { lhs, rhs in
            score(lhs.element) < score(rhs.element)
        }?.offset
    }

    nonisolated private static func score(_ descriptor: WindowDescriptor) -> Int {
        var value = 0
        if descriptor.isVisible { value += 2 }
        if descriptor.hasMainIdentifier { value += 1 }
        return value
    }
}

/// Centralized, robust show sequence for the main window used by every entry point
/// (menu bar "Open Mumble", Dock reopen, etc.).
///
/// Menu-bar (`.accessory`) apps cannot reliably order a window front until the app has
/// been promoted to `.regular` and given a beat to settle, then activated. See
/// https://developer.apple.com/forums/thread/836619 and the menu-bar activation writeups.
@MainActor
enum MainWindowPresenter {
    /// Delay after promoting to `.regular` before activating — macOS needs a beat to
    /// process the policy change or the window never becomes key.
    private static let policySettleDelay: Duration = .milliseconds(100)
    /// How long to wait for SwiftUI to (re)create the window when none exists yet.
    private static let recreateTimeout: Duration = .seconds(2)
    private static let recreatePollInterval: Duration = .milliseconds(50)

    private static var showTask: Task<Void, Never>?

    /// Show and focus the main window. Coalesces overlapping calls.
    static func show() {
        if let existing = showTask, !existing.isCancelled {
            return
        }
        showTask = Task { @MainActor in
            await performShow()
            showTask = nil
        }
    }

    private static func performShow() async {
        ActivationPolicyController.beginShowingMainWindow()

        NSApp.setActivationPolicy(.regular)
        try? await Task.sleep(for: policySettleDelay)
        NSApp.activate(ignoringOtherApps: true)

        if let window = mainWindow() {
            bringToFront(window)
        } else {
            // Window not created yet (or was released): ask SwiftUI to build it, then wait.
            NotificationCenter.default.post(name: .mumbleOpenMainWindow, object: nil)
            if let window = await waitForMainWindow() {
                bringToFront(window)
            }
        }

        // Clear the suppress flag first so recompute reflects reality: if the window
        // never appeared, we correctly demote back to `.accessory`.
        ActivationPolicyController.endShowingMainWindow()
        ActivationPolicyController.recompute()
    }

    static func mainWindow() -> NSWindow? {
        let windows = NSApp.windows
        let descriptors = windows.map(descriptor(for:))
        guard let index = MainWindowSelection.bestIndex(in: descriptors) else { return nil }
        return windows[index]
    }

    private static func descriptor(for window: NSWindow) -> WindowDescriptor {
        WindowDescriptor(
            isPanel: window is NSPanel,
            isVisible: window.isVisible,
            canBecomeMain: window.canBecomeMain,
            hasMainIdentifier: window.identifier?.rawValue.hasPrefix("main") ?? false
        )
    }

    private static func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private static func waitForMainWindow() async -> NSWindow? {
        let deadline = ContinuousClock.now.advanced(by: recreateTimeout)
        while ContinuousClock.now < deadline {
            if let window = mainWindow() { return window }
            try? await Task.sleep(for: recreatePollInterval)
        }
        return mainWindow()
    }
}
