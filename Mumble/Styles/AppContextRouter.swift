import Foundation

/// Maps frontmost app bundle IDs to style presets for auto-routing.
struct AppContextRouter: Sendable {
    static let map: [String: StylePreset] = [
        "com.apple.mail": .email,
        "com.microsoft.VSCode": .code,
        "com.apple.dt.Xcode": .code,
        "com.tinyspeck.slackmacgap": .casual,
        "com.google.Chrome": .neutral,
    ]

    func preset(forFrontmostBundleID id: String?) -> StylePreset {
        guard let id else { return .neutral }
        return Self.map[id] ?? .neutral
    }
}
