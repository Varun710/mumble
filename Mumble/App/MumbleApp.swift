import SwiftUI

@main
struct MumbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(env)
                .modelContainer(env.container)
                .frame(minWidth: 920, minHeight: 600)
                .task { env.bootstrap() }
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Recording") { env.recorder.toggle() }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("Flow", systemImage: "waveform") {
            MenuBarContent()
                .environment(env)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environment(env)
                .modelContainer(env.container)
                .frame(width: 640, height: 560)
                .preferredColorScheme(.dark)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Flow") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        Divider()
        Text("Hold the dictation hotkey to dictate")
        Divider()
        Button("Quit Flow") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
