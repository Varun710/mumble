import Foundation
import SwiftUI

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
        false
    }
}

struct RecordingLibraryCommandContext {
    var selectAll: () -> Void
    var deleteSelection: () -> Void
    var canSelectAll: Bool
    var canDelete: Bool
}

private struct RecordingLibraryCommandContextKey: FocusedValueKey {
    typealias Value = RecordingLibraryCommandContext
}

extension FocusedValues {
    var recordingLibraryCommandContext: RecordingLibraryCommandContext? {
        get { self[RecordingLibraryCommandContextKey.self] }
        set { self[RecordingLibraryCommandContextKey.self] = newValue }
    }
}
