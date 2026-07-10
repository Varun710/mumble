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
                .background(MainWindowOpenBridge())
                .preferredColorScheme(env.settings.appearance.colorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 720)
        .commands {
            MumbleCommands(env: env)
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

private struct MumbleCommands: Commands {
    let env: AppEnvironment
    @FocusedValue(\.recordingLibraryCommandContext) private var recordingLibraryCommandContext

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Recording") { env.recorder.toggle() }
                .keyboardShortcut("n", modifiers: .command)
        }

        CommandMenu("Recordings") {
            Button("Select All Recordings") {
                recordingLibraryCommandContext?.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(recordingLibraryCommandContext?.canSelectAll != true)

            Button("Delete Selected Recordings", role: .destructive) {
                recordingLibraryCommandContext?.deleteSelection()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(recordingLibraryCommandContext?.canDelete != true)
        }

        CommandGroup(replacing: .appTermination) {
            Button("Quit Mumble") {
                env.shutdown()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

/// Bridges the AppKit layer back into SwiftUI: when `MainWindowPresenter` cannot find an
/// existing main window, it posts `.mumbleOpenMainWindow` and this view recreates it via
/// the scene's `openWindow` action. The view tree stays alive while the window is merely
/// hidden (`orderOut`), so this reliably re-shows a hidden window too.
private struct MainWindowOpenBridge: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .mumbleOpenMainWindow)) { _ in
                openWindow(id: "main")
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
