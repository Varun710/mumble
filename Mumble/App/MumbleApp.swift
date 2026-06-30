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

        MenuBarExtra("Mumble", image: "MenuBarSymbol") {
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
        Button(env.dictation.isActive ? "Stop Dictation" : "Start Dictation") {
            env.dictation.toggle()
        }
        Text(env.dictation.isActive ? "Listening… click to stop & paste" : "Or hold ⌃⌥Space anywhere to dictate")
            .font(.caption)

        Divider()

        Button("Open Mumble") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        SettingsLink { Text("Settings…") }

        Divider()

        Button("Quit Mumble") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
