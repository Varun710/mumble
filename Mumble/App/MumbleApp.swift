import SwiftUI

@main
struct MumbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private var env: AppEnvironment { appDelegate.env }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(env)
                .modelContainer(env.container)
                .frame(minWidth: 920, minHeight: 600)
                .background(MainWindowLifecycle())
                .preferredColorScheme(env.settings.appearance.colorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Recording") { env.recorder.toggle() }
                    .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Mumble") {
                    env.shutdown()
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }

        Settings {
            SettingsView()
                .environment(env)
                .modelContainer(env.container)
                .frame(width: 640, height: 560)
                .preferredColorScheme(env.settings.appearance.colorScheme)
        }
    }
}

/// Hooks the main window close button to hide (menu-bar mode) instead of quitting.
private struct MainWindowLifecycle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window, !(window is NSPanel) else { return }
            window.isReleasedWhenClosed = false
            if window.delegate == nil {
                window.delegate = context.coordinator
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            ActivationPolicyController.recompute()
            return false
        }
    }
}
