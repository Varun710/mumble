import AVFoundation
import AppKit
import ApplicationServices
import Observation

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
}

/// Tracks and requests the permissions the app needs:
/// Microphone, Accessibility (PostEvent, for synthesized paste), Input Monitoring (global hotkey),
/// and Menu Bar allow-list (macOS 26+).
@MainActor
@Observable
final class PermissionsService {
    var microphone: PermissionState = .notDetermined
    var accessibility: PermissionState = .notDetermined
    var inputMonitoring: PermissionState = .notDetermined
    var menuBar: PermissionState = {
        if #available(macOS 26, *) { return .notDetermined }
        return .granted
    }()

    private weak var menuBarController: MenuBarController?

    func bind(menuBar: MenuBarController) {
        menuBarController = menuBar
    }

    /// Whether the Menu Bar allow-list applies on this macOS version.
    static var menuBarPermissionRequired: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    func refresh() {
        microphone = Self.microphoneState()
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        inputMonitoring = Self.inputMonitoringState()
        menuBar = Self.menuBarState(menuBar: menuBarController)
    }

    // MARK: Microphone

    static func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    @discardableResult
    func requestMicrophone() async -> Bool {
        if microphone == .granted { return true }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphone = granted ? .granted : .denied
        return granted
    }

    // MARK: Accessibility (PostEvent)

    /// Prompts and registers the app in System Settings > Privacy & Security > Accessibility.
    @discardableResult
    func requestAccessibility(prompt: Bool = true) -> Bool {
        // Documented value of kAXTrustedCheckOptionPrompt; used directly to avoid
        // touching the non-concurrency-safe global symbol.
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibility = trusted ? .granted : .denied
        return trusted
    }

    // MARK: Input Monitoring

    static func inputMonitoringState() -> PermissionState {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: return .granted
        case kIOHIDAccessTypeDenied: return .denied
        default: return .notDetermined
        }
    }

    @discardableResult
    func requestInputMonitoring() -> Bool {
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        inputMonitoring = granted ? .granted : .denied
        return granted
    }

    // MARK: Menu Bar (macOS 26+ allow-list)

    static func menuBarState(menuBar: MenuBarController?) -> PermissionState {
        guard menuBarPermissionRequired else { return .granted }
        return MenuBarVisibilityChecker.isAllowed(menuBar: menuBar) ? .granted : .denied
    }

    /// Opens System Settings → Menu Bar so the user can allow Mumble.
    @discardableResult
    func requestMenuBar() -> Bool {
        openMenuBarSettings()
        menuBar = Self.menuBarState(menuBar: menuBarController)
        return menuBar == .granted
    }

    // MARK: Settings deep links

    func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openMenuBarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.MenuBarSettings") {
            NSWorkspace.shared.open(url)
            return
        }
        open("x-apple.systempreferences:com.apple.ControlCenter-Settings.extension?MenuBar")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
