import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: SidebarItem = .home

    var body: some View {
        ZStack {
            AmbientBackground()

            HStack(spacing: 12) {
                MumbleGlassContainer {
                    SidebarView(selection: $selection)
                        .frame(maxHeight: .infinity)
                        .glassPanel(cornerRadius: 20)
                }
                .frame(width: 248)

                centerPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selection.showsRecordingPanel {
                    MumbleGlassContainer {
                        RecordingPanel(selection: $selection)
                            .frame(maxHeight: .infinity)
                            .glassPanel(cornerRadius: 20)
                    }
                    .frame(width: 320)
                }
            }
            .padding(12)
        }
        .foregroundStyle(Theme.textPrimary(for: colorScheme))
        .onAppear {
            env.dictation.startMonitoring()
            env.permissions.refresh()
        }
        .onChange(of: env.recorder.lastSavedID) { _, newValue in
            if let id = newValue { selection = .recording(id) }
        }
        .sheet(isPresented: Binding(
            get: { env.needsOnboarding },
            set: { presented in if !presented { env.finishOnboarding() } }
        )) {
            OnboardingView(onFinish: { env.finishOnboarding() })
        }
    }

    @ViewBuilder
    private var centerPane: some View {
        switch selection {
        case .home:
            HomeView(selection: $selection)
        case .recordings:
            RecordingsListView(selection: $selection)
        case .notes:
            NotesView(selection: $selection)
        case .settings:
            SettingsView()
        case .recording(let id):
            RecordingDetailView(recordingID: id, selection: $selection)
        }
    }
}
