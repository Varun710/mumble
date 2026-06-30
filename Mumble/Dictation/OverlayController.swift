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
    /// Live mic RMS levels (0...1) while listening.
    var levels: [Float] = []
    /// Seconds elapsed since dictation started.
    var elapsed: TimeInterval = 0
    /// Stable live caption text during listening.
    var confirmedCaption: String = ""
    /// Draft tail of the live caption (may revise).
    var draftCaption: String = ""
}

/// Shared overlay dimensions — all phases use the same compact pill size.
enum OverlayLayout {
    /// Matches `DictationStatusPill` intrinsic width.
    static let width: CGFloat = 389
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
        let didChange = appearance != mode
        appearance = mode
        if didChange {
            refreshRootView()
        }
        applyOverlayAppearance()
    }

    func show() {
        let state = signposter.beginInterval("show")
        defer { signposter.endInterval("show", state) }

        let panel = panel ?? makePanel()
        self.panel = panel
        ensureHostingView(on: panel)
        applyOverlayAppearance()

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
        model.levels = []
        model.elapsed = 0
        model.confirmedCaption = ""
        model.draftCaption = ""
        AppLog.overlay.debug("hide")
    }

    /// Re-measure and reposition after live caption text changes.
    func invalidateLayout() {
        guard panel != nil, model.phase == .listening else { return }
        resizePanelToFit()
        if let panel { position(panel) }
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
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
            hostingView = hosting

            let container = makeGlassContainer(hosting: hosting)
            container.translatesAutoresizingMaskIntoConstraints = true
            glassContainer = container
            panel.contentView = container
            applyOverlayAppearance()
        }
    }

    private func makeGlassContainer(hosting: NSHostingView<OverlayRootView>) -> NSView {
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.appearance = nsAppearance
            glass.cornerRadius = 22
            hosting.autoresizingMask = [.width, .height]
            glass.contentView = hosting
            return glass
        }

        let effect = NSVisualEffectView()
        effect.material = overlayMaterial
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = nsAppearance
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 22
        effect.layer?.masksToBounds = true
        hosting.frame = effect.bounds
        hosting.autoresizingMask = [.width, .height]
        effect.addSubview(hosting)
        return effect
    }

    private func refreshRootView() {
        hostingView?.rootView = makeRootView()
    }

    private func applyOverlayAppearance() {
        panel?.appearance = nsAppearance
        glassContainer?.appearance = nsAppearance
        if let effect = glassContainer as? NSVisualEffectView {
            effect.material = overlayMaterial
        }
    }

    private func makeRootView() -> OverlayRootView {
        OverlayRootView(model: model, appearance: appearance)
    }

    private var nsAppearance: NSAppearance? {
        switch appearance {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    private var overlayMaterial: NSVisualEffectView.Material {
        resolvedColorScheme == .light ? .popover : .hudWindow
    }

    private var resolvedColorScheme: ColorScheme {
        switch appearance {
        case .light: return .light
        case .dark: return .dark
        case .system:
            let bestMatch = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
            return bestMatch == .aqua ? .light : .dark
        }
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
        hosting.setFrameSize(size)
        hosting.frame.origin = .zero
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.clear)
            .preferredColorScheme(appearance.colorScheme)
    }
}
