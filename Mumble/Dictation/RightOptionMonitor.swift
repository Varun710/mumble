import AppKit
import CoreGraphics

/// Detects holding the **Right Option** key globally (over any app) using a
/// CGEventTap on `.flagsChanged`. Requires Input Monitoring permission.
@MainActor
final class RightOptionMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    /// Fired when Right Option was pressed but a chord (other modifier/key) cancelled dictation.
    var onChordCancelled: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDown = false
    private var chordDetected = false

    /// Right Option physical key code.
    nonisolated private static let rightOptionKeyCode: Int64 = 61
    /// Device-dependent flag bit set when the *right* Option key is held.
    nonisolated private static let rightOptionFlag: UInt64 = 0x40

    /// Modifiers that cancel dictation when held with Right Option.
    /// Excludes `.maskAlternate` — Right Option itself sets that flag.
    nonisolated private static let otherModifierMask: CGEventFlags = [
        .maskCommand, .maskControl, .maskShift, .maskSecondaryFn, .maskHelp
    ]
    /// Left Option flag; distinct from Right Option (0x40).
    nonisolated private static let leftOptionFlag: UInt64 = 0x20

    var isRunning: Bool { eventTap != nil }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let flagsMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        let keyMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let mask = flagsMask | keyMask
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
        chordDetected = false
    }

    nonisolated private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            MainActor.assumeIsolated {
                if let tap = self.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return
        }

        if type == .keyDown {
            MainActor.assumeIsolated {
                guard self.isDown, !self.chordDetected else { return }
                self.chordDetected = true
                self.isDown = false
                self.onChordCancelled?()
            }
            return
        }

        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Self.rightOptionKeyCode else { return }
        let down = (event.flags.rawValue & Self.rightOptionFlag) != 0
        let otherModifiers = event.flags.intersection(Self.otherModifierMask)
        let leftOptionDown = (event.flags.rawValue & Self.leftOptionFlag) != 0

        MainActor.assumeIsolated {
            if down, !self.isDown {
                if !otherModifiers.isEmpty || leftOptionDown {
                    self.chordDetected = true
                    self.onChordCancelled?()
                    return
                }
                self.chordDetected = false
                self.isDown = true
                self.onPress?()
            } else if !down, self.isDown {
                self.isDown = false
                if self.chordDetected {
                    self.chordDetected = false
                } else {
                    self.onRelease?()
                }
            }
        }
    }
}
