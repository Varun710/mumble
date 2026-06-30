import AppKit
import CoreGraphics

/// Pastes text into the frontmost application by writing to the pasteboard
/// and synthesizing Cmd+V. Requires Accessibility (PostEvent) permission and
/// only works in a non-sandboxed build.
@MainActor
final class PasteService {
    private let clipboard = ClipboardService()
    private static let vKeyCode: CGKeyCode = 0x09

    /// - Parameters:
    ///   - text: text to insert at the cursor in the active app.
    ///   - copyToClipboard: when false, paste then restore so the clipboard is untouched.
    ///   - restoreClipboard: restore the previous clipboard after pasting.
    func paste(_ text: String, copyToClipboard: Bool, restoreClipboard: Bool) {
        let saved = restoreClipboard ? clipboard.snapshot() : []
        clipboard.copy(text)

        // Give the previously focused app a moment to regain key focus after the
        // overlay panel is ordered out, then synthesize Cmd+V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            self.synthesizePaste()

            if restoreClipboard && !copyToClipboard {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.clipboard.restore(saved)
                }
            }
        }
    }

    private func synthesizePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: Self.vKeyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
