import AVFoundation
import AppKit
import ApplicationServices
import Observation

enum PermissionState: Equatable {
    case granted
    case denied
    case notDetermined
}

/// Tracks and requests the three permissions the app needs:
/// Microphone, Accessibility (PostEvent, for synthesized paste), and Input Monitoring (global hotkey).
@MainActor
@Observable
final class PermissionsService {
    var microphone: PermissionState = .notDetermined
    var accessibility: PermissionState = .notDetermined
    var inputMonitoring: PermissionState = .notDetermined

    func refresh() {
        microphone = Self.microphoneState()
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        inputMonitoring = Self.inputMonitoringState()
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

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
