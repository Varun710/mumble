import AppKit

/// Ensures Tahoe / Sonoma Control Center sees a status item from an accessory app.
@MainActor
enum MenuBarRegistration {
    private static let legacyBundleID = "com.mumble.app"

    /// Control Center registers menu bar items more reliably when created under `.accessory`.
    /// Call before `NSStatusItem` creation, then let `ActivationPolicyController` promote to `.regular`.
    static func prepareForStatusItem() {
        guard NSApp.activationPolicy() != .accessory else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Tahoe can wedge a bundle id when repeated local rebuilds hide status items.
    static func clearStaleStatusItemDefaults() {
        let defaults = UserDefaults.standard
        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.contains("NSStatusItem") || key.contains("VisibleCC") else { continue }
            if value as? Int == 0 || value as? Bool == false {
                defaults.removeObject(forKey: key)
            }
        }
        guard var legacy = UserDefaults.standard.persistentDomain(forName: legacyBundleID) else { return }
        var changed = false
        for key in legacy.keys where key.contains("NSStatusItem") || key.contains("VisibleCC") {
            legacy.removeValue(forKey: key)
            changed = true
        }
        if changed {
            UserDefaults.standard.setPersistentDomain(legacy, forName: legacyBundleID)
        }
    }
}
