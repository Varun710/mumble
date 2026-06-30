import AppKit
import CoreGraphics

/// Detects holding the **Right Option** key globally (over any app) using a
/// listen-only CGEventTap on `.flagsChanged`. Requires Input Monitoring
/// permission; `start()` returns false if the tap could not be created.
@MainActor
final class RightOptionMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDown = false

    /// Right Option physical key code.
    nonisolated private static let rightOptionKeyCode: Int64 = 61
    /// Device-dependent flag bit set when the *right* Option key is held.
    nonisolated private static let rightOptionFlag: UInt64 = 0x40

    var isRunning: Bool { eventTap != nil }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                if let refcon {
                    let monitor = Unmanaged<RightOptionMonitor>.fromOpaque(refcon).takeUnretainedValue()
                    monitor.handle(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        isDown = false
    }

    /// Runs on the main run loop (the tap is attached to it), so MainActor access is safe.
    nonisolated private func handle(type: CGEventType, event: CGEvent) {
        // The tap can be disabled by the system under load; re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            MainActor.assumeIsolated {
                if let tap = self.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return
        }
        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Self.rightOptionKeyCode else { return }
        let down = (event.flags.rawValue & Self.rightOptionFlag) != 0

        MainActor.assumeIsolated {
            if down, !self.isDown {
                self.isDown = true
                self.onPress?()
            } else if !down, self.isDown {
                self.isDown = false
                self.onRelease?()
            }
        }
    }
}
