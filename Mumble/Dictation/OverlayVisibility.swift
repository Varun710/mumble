import CoreGraphics
import Foundation

/// Pure helpers for overlay visibility and placement — unit-testable without AppKit windows.
enum OverlayVisibility {
    /// Content opacity is driven by an explicit presented flag (set in `show`/`hide`),
    /// never by SwiftUI `onAppear`, which can miss on non-activating / accessory panels.
    nonisolated static func contentOpacity(isPresented: Bool) -> Double {
        isPresented ? 1 : 0
    }

    /// Prefer the screen under the mouse; fall back to main, then first.
    nonisolated static func targetScreenIndex(
        mouseLocation: CGPoint,
        screens: [CGRect],
        mainIndex: Int?
    ) -> Int? {
        if let index = screens.firstIndex(where: { $0.contains(mouseLocation) }) {
            return index
        }
        if let mainIndex, screens.indices.contains(mainIndex) {
            return mainIndex
        }
        return screens.isEmpty ? nil : 0
    }

    nonisolated static func bottomCenterOrigin(
        visibleFrame: CGRect,
        panelSize: CGSize,
        bottomOffset: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.minY + bottomOffset
        )
    }
}
