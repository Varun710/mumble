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
    private var glassContainer: NSView?
    private var appearance: AppearanceMode = .system
    private var lastSizedPhase: OverlayModel.Phase?
    private let signposter = OSSignposter(subsystem: AppLog.subsystem, category: "Overlay")

    private static let minPanelWidth: CGFloat = 360
    private static let minPanelHeight: CGFloat = 52

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

            let container = makeGlassContainer(hosting: hosting)
            container.translatesAutoresizingMaskIntoConstraints = true
            glassContainer = container
            panel.contentView = container
        }
    }

    private func makeGlassContainer(hosting: NSHostingView<OverlayRootView>) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = 22
            glass.contentView = hosting
            return glass
        }

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)
        return effect
    }

    private func refreshRootView() {
        hostingView?.rootView = makeRootView()
    }

    private func makeRootView() -> OverlayRootView {
        OverlayRootView(model: model, appearance: appearance)
    }

    private func resizePanelToFit() {
        guard let hosting = hostingView, let panel else { return }
        hosting.layoutSubtreeIfNeeded()
        let fit = hosting.fittingSize
        let width = max(fit.width, Self.minPanelWidth)
        let height = max(fit.height, Self.minPanelHeight)
        let size = NSSize(width: width, height: height)
        panel.setContentSize(size)
        glassContainer?.setFrameSize(size)
        hosting.setFrameSize(hosting.fittingSize)
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
