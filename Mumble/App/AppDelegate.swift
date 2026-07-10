import AppKit

#if DEBUG
private func installUncaughtExceptionLogger() {
    NSSetUncaughtExceptionHandler { exception in
        AppLog.lifecycle.fault(
            "uncaught NSException name=\(exception.name.rawValue, privacy: .public) reason=\(exception.reason ?? "nil", privacy: .public)"
        )
    }
}
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let env = AppEnvironment()
    private var didBootstrap = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        if #available(macOS 26, *) {
            // Tahoe: register the MenuBarExtra from accessory policy before the main window promotes to regular.
            MenuBarRegistration.prepareForStatusItem()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        installUncaughtExceptionLogger()
        #endif
        AppLog.lifecycle.info("applicationDidFinishLaunching")
        bootstrapIfNeeded()

        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { ActivationPolicyController.recompute() }
        }
        center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            let window = note.object as? NSWindow
            MainActor.assumeIsolated { ActivationPolicyController.recompute(excluding: window) }
        }
        center.addObserver(forName: .mumbleQuit, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.env.shutdown() }
        }
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.env.menuBar.recreateIfNeeded()
                self?.env.permissions.refresh()
            }
        }
        ActivationPolicyController.recompute()
        env.permissions.refresh()
    }

    func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        env.bootstrap()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.lifecycle.info("applicationWillTerminate")
        env.shutdown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowPresenter.show()
        }
        return true
    }
}
