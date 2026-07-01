import Foundation

/// A single word (or token) with timing from an ASR engine.
struct TranscriptWord: Sendable, Equatable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
}
