import AppKit

/// Toggles the app between `.accessory` (menu-bar only, no Dock icon) and
/// `.regular` (Dock icon + menu) depending on whether a real window is visible.
/// The floating overlay panel is excluded so it never forces a Dock icon.
@MainActor
enum ActivationPolicyController {
    static func recompute(excluding closing: NSWindow? = nil) {
        let hasMainWindow = NSApp.windows.contains { window in
            window !== closing
                && !(window is NSPanel)
                && window.isVisible
                && window.canBecomeMain
        }
        let desired: NSApplication.ActivationPolicy = hasMainWindow ? .regular : .accessory
        guard NSApp.activationPolicy() != desired else { return }
        NSApp.setActivationPolicy(desired)
        if desired == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
