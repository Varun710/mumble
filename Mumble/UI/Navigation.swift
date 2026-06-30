import Foundation

/// What the center pane is currently showing.
enum SidebarItem: Hashable {
    case home
    case recordings
    case notes
    case settings
    case recording(UUID)

    var isPrimary: Bool {
        switch self {
        case .home, .recordings, .notes, .settings: return true
        case .recording: return false
        }
    }

    /// Whether the right-hand recording panel is visible for this item.
    var showsRecordingPanel: Bool {
        switch self {
        case .home, .recordings, .recording: return true
        case .notes, .settings: return false
        }
    }
}
