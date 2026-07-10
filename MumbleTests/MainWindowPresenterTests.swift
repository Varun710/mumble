import AppKit
import XCTest
@testable import Mumble

final class MainWindowPresenterTests: XCTestCase {
    // MARK: - Policy

    func testDesiredPolicyRegularWhenMainWindowVisible() {
        XCTAssertEqual(MainWindowPolicy.desired(hasVisibleMainWindow: true), .regular)
    }

    func testDesiredPolicyAccessoryWhenNoMainWindow() {
        XCTAssertEqual(MainWindowPolicy.desired(hasVisibleMainWindow: false), .accessory)
    }

    // MARK: - Demotion suppression

    func testDemotionSuppressedWhileShowInProgress() {
        // Even with no visible window, we must not demote mid-show.
        XCTAssertFalse(
            MainWindowPolicy.shouldAllowDemotion(showInProgress: true, hasVisibleMainWindow: false)
        )
    }

    func testDemotionAllowedWhenIdleAndNoWindow() {
        XCTAssertTrue(
            MainWindowPolicy.shouldAllowDemotion(showInProgress: false, hasVisibleMainWindow: false)
        )
    }

    func testDemotionNotNeededWhenWindowVisible() {
        // A visible window means desired == .regular, so demotion should not be allowed.
        XCTAssertFalse(
            MainWindowPolicy.shouldAllowDemotion(showInProgress: false, hasVisibleMainWindow: true)
        )
    }

    // MARK: - Window selection

    func testSelectionNilWhenOnlyPanels() {
        let windows = [
            WindowDescriptor(isPanel: true, isVisible: true, canBecomeMain: false, hasMainIdentifier: false),
            WindowDescriptor(isPanel: true, isVisible: false, canBecomeMain: false, hasMainIdentifier: false),
        ]
        XCTAssertNil(MainWindowSelection.bestIndex(in: windows))
    }

    func testSelectionNilWhenNoMainCapableWindow() {
        let windows = [
            WindowDescriptor(isPanel: false, isVisible: true, canBecomeMain: false, hasMainIdentifier: false),
        ]
        XCTAssertNil(MainWindowSelection.bestIndex(in: windows))
    }

    func testSelectionPicksHiddenMainWindowOverPanel() {
        // The real "won't open" scenario: a hidden (orderOut) main window still in NSApp.windows.
        let windows = [
            WindowDescriptor(isPanel: true, isVisible: true, canBecomeMain: false, hasMainIdentifier: false),
            WindowDescriptor(isPanel: false, isVisible: false, canBecomeMain: true, hasMainIdentifier: true),
        ]
        XCTAssertEqual(MainWindowSelection.bestIndex(in: windows), 1)
    }

    func testSelectionPrefersVisibleMainWindow() {
        let windows = [
            WindowDescriptor(isPanel: false, isVisible: false, canBecomeMain: true, hasMainIdentifier: false),
            WindowDescriptor(isPanel: false, isVisible: true, canBecomeMain: true, hasMainIdentifier: false),
        ]
        XCTAssertEqual(MainWindowSelection.bestIndex(in: windows), 1)
    }

    func testSelectionPrefersMainIdentifierAmongEqualVisibility() {
        let windows = [
            WindowDescriptor(isPanel: false, isVisible: true, canBecomeMain: true, hasMainIdentifier: false),
            WindowDescriptor(isPanel: false, isVisible: true, canBecomeMain: true, hasMainIdentifier: true),
        ]
        XCTAssertEqual(MainWindowSelection.bestIndex(in: windows), 1)
    }

    func testEligibilityExcludesPanelsAndNonMainWindows() {
        XCTAssertFalse(
            MainWindowSelection.isEligible(
                WindowDescriptor(isPanel: true, isVisible: true, canBecomeMain: true, hasMainIdentifier: true)
            )
        )
        XCTAssertFalse(
            MainWindowSelection.isEligible(
                WindowDescriptor(isPanel: false, isVisible: true, canBecomeMain: false, hasMainIdentifier: false)
            )
        )
        XCTAssertTrue(
            MainWindowSelection.isEligible(
                WindowDescriptor(isPanel: false, isVisible: false, canBecomeMain: true, hasMainIdentifier: false)
            )
        )
    }

    // MARK: - Suppress flag lifecycle (integration with ActivationPolicyController)

    @MainActor
    func testShowInProgressFlagBalances() {
        XCTAssertFalse(ActivationPolicyController.isShowingMainWindow)
        ActivationPolicyController.beginShowingMainWindow()
        XCTAssertTrue(ActivationPolicyController.isShowingMainWindow)
        ActivationPolicyController.beginShowingMainWindow()
        ActivationPolicyController.endShowingMainWindow()
        XCTAssertTrue(ActivationPolicyController.isShowingMainWindow)
        ActivationPolicyController.endShowingMainWindow()
        XCTAssertFalse(ActivationPolicyController.isShowingMainWindow)
    }

    @MainActor
    func testEndShowingNeverGoesNegative() {
        ActivationPolicyController.endShowingMainWindow()
        ActivationPolicyController.endShowingMainWindow()
        XCTAssertFalse(ActivationPolicyController.isShowingMainWindow)
        // A subsequent begin still flips it true (counter clamped at 0, not negative).
        ActivationPolicyController.beginShowingMainWindow()
        XCTAssertTrue(ActivationPolicyController.isShowingMainWindow)
        ActivationPolicyController.endShowingMainWindow()
        XCTAssertFalse(ActivationPolicyController.isShowingMainWindow)
    }
}
