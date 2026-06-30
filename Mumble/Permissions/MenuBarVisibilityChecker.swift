import AppKit

/// Best-effort detection for macOS 26 Tahoe's menu bar allow-list.
/// Apple provides no public API; blocked items may still report `isVisible == true`.
@MainActor
enum MenuBarVisibilityChecker {
    static func isAllowed(menuBar: MenuBarController?) -> Bool {
        guard #available(macOS 26, *) else { return true }
        if let menuBar, menuBar.hasStatusItem {
            return menuBar.isIconOnScreen
        }
        return probeStatusItemIsOnScreen()
    }

    /// Whether a status item button is actually placed on the visible menu bar.
    static func statusItemIsOnScreen(button: NSStatusBarButton) -> Bool {
        guard !button.isHidden, button.alphaValue > 0.01 else { return false }
        guard button.frame.width > 0, button.frame.height > 0 else { return false }
        guard let window = button.window else { return false }
        guard window.frame.width > 0, window.frame.height > 0 else { return false }

        // Blocked Tahoe items often park below the desktop (e.g. y = -22) or lack a screen.
        guard let screen = window.screen else { return false }
        guard window.frame.minY >= 0 else { return false }

        // Visible items align with the top menu bar band on their screen.
        let menuBarMaxY = screen.frame.maxY
        let thickness = NSStatusBar.system.thickness
        let bandBottom = menuBarMaxY - thickness - 2
        guard window.frame.maxY >= bandBottom else { return false }

        if #available(macOS 14, *) {
            guard window.occlusionState.contains(.visible) else { return false }
        }

        return true
    }

    private static func probeStatusItemIsOnScreen() -> Bool {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer { NSStatusBar.system.removeStatusItem(item) }

        item.isVisible = true
        if let button = item.button {
            let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Mumble")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        }

        let deadline = Date().addingTimeInterval(0.35)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: deadline)
        }

        guard let button = item.button else { return false }
        return statusItemIsOnScreen(button: button)
    }
}
