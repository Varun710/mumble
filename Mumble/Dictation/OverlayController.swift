import AppKit
import SwiftUI
import Observation
import OSLog

/// Observable state rendered by the floating overlay capsule.
@MainActor
@Observable
final class OverlayModel {
    enum Phase: Equatable { case listening, transcribing, done, error }
    var phase: Phase = .listening
    var message: String = ""
    var modelName: String = ""
}

/// Shows/hides the floating dictation capsule.
@MainActor
final class OverlayController {
    let model = OverlayModel()
    private var panel: OverlayPanel?
    private var hostingView: NSHostingView<OverlayRootView>?
    private var appearance: AppearanceMode = .system
    private var lastSizedPhase: OverlayModel.Phase?
    private let signposter = OSSignposter(subsystem: AppLog.subsystem, category: "Overlay")

    func setAppearance(_ mode: AppearanceMode) {
        guard appearance != mode else { return }
        appearance = mode
        refreshRootView()
    }

    func show() {
        let state = signposter.beginInterval("show")
        defer { signposter.endInterval("show", state) }

        let panel = panel ?? makePanel()
        self.panel = panel
        ensureHostingView(on: panel)

        if lastSizedPhase != model.phase {
            resizePanelToFit()
            lastSizedPhase = model.phase
        }

        position(panel)
        panel.orderFrontRegardless()
        AppLog.overlay.debug("show phase=\(String(describing: self.model.phase), privacy: .public)")
    }

    func hide() {
        panel?.orderOut(nil)
        lastSizedPhase = nil
        AppLog.overlay.debug("hide")
    }

    private func makePanel() -> OverlayPanel {
        let panel = OverlayPanel()
        ensureHostingView(on: panel)
        return panel
    }

    private func ensureHostingView(on panel: OverlayPanel) {
        if hostingView == nil {
            let hosting = NSHostingView(rootView: makeRootView())
            hosting.translatesAutoresizingMaskIntoConstraints = true
            hostingView = hosting
            panel.contentView = hosting
        }
    }

    private func refreshRootView() {
        hostingView?.rootView = makeRootView()
    }

    private func makeRootView() -> OverlayRootView {
        OverlayRootView(model: model, appearance: appearance)
    }

    private func resizePanelToFit() {
        guard let hosting = hostingView, let panel else { return }
        let size = hosting.fittingSize
        panel.setContentSize(NSSize(width: max(size.width, 1), height: max(size.height, 1)))
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
