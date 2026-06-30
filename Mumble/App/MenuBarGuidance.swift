import AppKit

/// One-time guidance when macOS Tahoe blocks the menu bar icon.
@MainActor
enum MenuBarGuidance {
    private static let hintKey = "didShowMenuBarAllowListHintV3"
    private static let hintDateKey = "didShowMenuBarAllowListHintAtV3"
    private static let reshowInterval: TimeInterval = 24 * 60 * 60

    static func checkAfterLaunch(menuBar: MenuBarController, permissions: PermissionsService) {
        guard PermissionsService.menuBarPermissionRequired else { return }
        Task { @MainActor in
            // Give MenuBarExtra / Control Center time to register on Tahoe.
            try? await Task.sleep(for: .seconds(3))
            let allowed = MenuBarVisibilityChecker.isAllowed(menuBar: menuBar.hasStatusItem ? menuBar : nil)
            guard !allowed else { return }
            permissions.menuBar = .denied
            presentIfNeeded()
        }
    }

    static func presentIfNeeded() {
        guard PermissionsService.menuBarPermissionRequired else { return }
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: hintKey) {
            let last = defaults.object(forKey: hintDateKey) as? Date ?? .distantPast
            guard Date().timeIntervalSince(last) >= reshowInterval else { return }
        }

        defaults.set(true, forKey: hintKey)
        defaults.set(Date(), forKey: hintDateKey)

        let alert = NSAlert()
        alert.messageText = "Mumble can't show its menu bar icon"
        alert.informativeText = """
            macOS Tahoe tracks menu bar apps per bundle ID. Repeated local rebuilds can wedge the old ID so the icon never appears and the app is missing from System Settings → Menu Bar.

            1. Quit Mumble completely (Mumble → Quit Mumble).
            2. Reopen Mumble from Applications — this build uses a fresh bundle ID.
            3. Open System Settings → Menu Bar → Allow in the Menu Bar.
            4. Turn Mumble on.

            Run ./scripts/diagnose-menu-bar.sh in Terminal if it is still missing.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "Dismiss")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.MenuBarSettings") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
