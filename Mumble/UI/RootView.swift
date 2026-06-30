import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: SidebarItem = .home
    @State private var recordingReturnRoute: SidebarItem = .recordings

    var body: some View {
        ZStack {
            AmbientBackground()

            HStack(spacing: 12) {
                MumbleGlassContainer {
                    SidebarView(selection: trackedSelection)
                        .frame(maxHeight: .infinity)
                        .glassPanel(cornerRadius: 20)
                }
                .frame(width: 248)

                MumbleGlassContainer {
                    centerPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .glassPanel(cornerRadius: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if selection.showsRecordingPanel {
                    MumbleGlassContainer {
                        RecordingPanel(selection: trackedSelection)
                            .frame(maxHeight: .infinity)
                            .glassPanel(cornerRadius: 20)
                    }
                    .frame(width: 320)
                }
            }
            .padding(12)
        }
        .foregroundStyle(Theme.textPrimary(for: colorScheme))
        .onChange(of: env.settings.appearance) { _, newValue in
            env.overlay.setAppearance(newValue)
        }
        .onAppear {
            env.dictation.startMonitoring()
            env.permissions.refresh()
        }
        .onChange(of: env.recorder.lastSavedID) { _, newValue in
            if let id = newValue {
                recordingReturnRoute = .recordings
                selection = .recording(id)
            }
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
            HomeView(selection: trackedSelection)
        case .recordings:
            RecordingsListView(selection: trackedSelection)
        case .notes:
            NotesView(selection: trackedSelection)
        case .settings:
            SettingsView()
        case .recording(let id):
            RecordingDetailView(recordingID: id, selection: trackedSelection, returnRoute: recordingReturnRoute)
        }
    }

    private var trackedSelection: Binding<SidebarItem> {
        Binding(
            get: { selection },
            set: { newSelection in
                if case .recording = newSelection, selection.isPrimary {
                    recordingReturnRoute = selection == .settings ? .recordings : selection
                }
                selection = newSelection
            }
        )
    }
}
