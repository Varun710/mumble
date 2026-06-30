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
        let host = NSHostingView(rootView: OverlayView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = true
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    private func position(_ panel: OverlayPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 60)
        panel.setFrameOrigin(origin)
    }
}
