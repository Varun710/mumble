import AppKit

/// Toggles the app between `.accessory` (menu-bar only, no Dock icon) and
/// `.regular` (Dock icon + menu) depending on whether a real window is visible.
/// The floating overlay panel is excluded so it never forces a Dock icon.
@MainActor
enum ActivationPolicyController {
    private static var showInProgressCount = 0

    /// True while a `MainWindowPresenter` show sequence is running. Used to suppress
    /// premature demotion to `.accessory` before the target window becomes visible.
    static var isShowingMainWindow: Bool { showInProgressCount > 0 }

    static func beginShowingMainWindow() {
        showInProgressCount += 1
    }

    static func endShowingMainWindow() {
        showInProgressCount = max(0, showInProgressCount - 1)
    }

    static func recompute(excluding closing: NSWindow? = nil) {
        let hasMainWindow = NSApp.windows.contains { window in
            window !== closing
                && !(window is NSPanel)
                && window.isVisible
                && window.canBecomeMain
        }
        let desired = MainWindowPolicy.desired(hasVisibleMainWindow: hasMainWindow)

        // Never demote to `.accessory` mid-show: the window may not be on screen yet.
        if desired == .accessory,
           !MainWindowPolicy.shouldAllowDemotion(showInProgress: isShowingMainWindow, hasVisibleMainWindow: hasMainWindow) {
            return
        }

        guard NSApp.activationPolicy() != desired else { return }
        NSApp.setActivationPolicy(desired)
        if desired == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
