import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var selection: SidebarItem = .home

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
                .frame(width: 248)

            Divider().overlay(Theme.separator)

            centerPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if selection.showsRecordingPanel {
                Divider().overlay(Theme.separator)
                RecordingPanel(selection: $selection)
                    .frame(width: 320)
            }
        }
        .background(Theme.windowBackground)
        .foregroundStyle(Theme.textPrimary)
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
