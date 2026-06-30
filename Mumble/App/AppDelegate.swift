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
        ActivationPolicyController.recompute()
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
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            }
            ActivationPolicyController.recompute()
        }
        return true
    }
}
