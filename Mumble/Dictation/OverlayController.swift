import AppKit
import SwiftUI
import Observation

/// Observable state rendered by the floating overlay capsule.
@MainActor
@Observable
final class OverlayModel {
    enum Phase: Equatable { case listening, transcribing, done, error }
    var phase: Phase = .listening
    var elapsed: TimeInterval = 0
    var levels: [Float] = []
    var message: String = ""
    var modelName: String = ""
}

/// Shows/hides the floating dictation capsule.
@MainActor
final class OverlayController {
    let model = OverlayModel()
    private var panel: OverlayPanel?
    private var appearance: AppearanceMode = .system

    func setAppearance(_ mode: AppearanceMode) {
        appearance = mode
        if panel != nil {
            panel?.contentView = makeHostingView()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel()
        panel.contentView = makeHostingView()
        return panel
    }

    private func makeHostingView() -> NSHostingView<OverlayRootView> {
        NSHostingView(
            rootView: OverlayRootView(model: model, appearance: appearance)
        )
    }

    private func position(_ panel: OverlayPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 72)
        panel.setFrameOrigin(origin)
    }
}

/// Hosts the overlay with the user's appearance preference.
private struct OverlayRootView: View {
    @Bindable var model: OverlayModel
    let appearance: AppearanceMode

    var body: some View {
        OverlayView(model: model)
            .preferredColorScheme(appearance.colorScheme)
    }
}
