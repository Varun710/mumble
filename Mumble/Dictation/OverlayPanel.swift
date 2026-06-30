import AppKit

/// Borderless, non-activating, always-on-top panel for the dictation capsule.
/// `.nonactivatingPanel` must be in the styleMask at init time.
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
