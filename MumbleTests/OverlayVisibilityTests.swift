import CoreGraphics
import XCTest
@testable import Mumble

final class OverlayVisibilityTests: XCTestCase {
    // MARK: - Content opacity (must not depend on SwiftUI onAppear)

    func testContentFullyVisibleWhenPresented() {
        XCTAssertEqual(OverlayVisibility.contentOpacity(isPresented: true), 1)
    }

    func testContentHiddenWhenNotPresented() {
        XCTAssertEqual(OverlayVisibility.contentOpacity(isPresented: false), 0)
    }

    // MARK: - Screen selection

    func testPicksScreenContainingMouse() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        ]
        let mouse = CGPoint(x: 1600, y: 100)
        XCTAssertEqual(
            OverlayVisibility.targetScreenIndex(mouseLocation: mouse, screens: screens, mainIndex: 0),
            1
        )
    }

    func testFallsBackToMainWhenMouseNotOnAnyScreen() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1920, height: 1080),
        ]
        let mouse = CGPoint(x: -100, y: -100)
        XCTAssertEqual(
            OverlayVisibility.targetScreenIndex(mouseLocation: mouse, screens: screens, mainIndex: 1),
            1
        )
    }

    func testFallsBackToFirstScreenWhenMainMissing() {
        let screens = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
        ]
        let mouse = CGPoint(x: -1, y: -1)
        XCTAssertEqual(
            OverlayVisibility.targetScreenIndex(mouseLocation: mouse, screens: screens, mainIndex: nil),
            0
        )
    }

    func testReturnsNilWhenNoScreens() {
        XCTAssertNil(
            OverlayVisibility.targetScreenIndex(
                mouseLocation: .zero,
                screens: [],
                mainIndex: nil
            )
        )
    }

    // MARK: - Bottom-center origin

    func testBottomCenterOrigin() {
        let visible = CGRect(x: 100, y: 50, width: 1400, height: 800)
        let size = CGSize(width: 389, height: 52)
        let origin = OverlayVisibility.bottomCenterOrigin(visibleFrame: visible, panelSize: size, bottomOffset: 72)
        XCTAssertEqual(origin.x, 100 + (1400 - 389) / 2, accuracy: 0.5)
        XCTAssertEqual(origin.y, 50 + 72, accuracy: 0.5)
    }
}
