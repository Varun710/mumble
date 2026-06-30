import Foundation
import SwiftData

/// A timestamped transcript segment belonging to a `Recording`.
@Model
final class Segment {
    var start: TimeInterval
    var end: TimeInterval
    var text: String
    var recording: Recording?

    init(start: TimeInterval, end: TimeInterval, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }

    var timestampLabel: String {
        let total = Int(start)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
