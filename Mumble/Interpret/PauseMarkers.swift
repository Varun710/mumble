import Foundation

enum PauseMarkers: Sendable {
    nonisolated static let threshold: Duration = .milliseconds(450)

    nonisolated static func inject(words: [ASRWord]) -> String {
        guard !words.isEmpty else { return "" }
        var out = ""
        var prevEnd: TimeInterval?
        for word in words {
            if let prevEnd, (word.start - prevEnd) >= thresholdSeconds {
                out += " <pause> "
            }
            out += word.text + " "
            prevEnd = word.end
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Inject pause markers using word timings; falls back to plain text when no words.
    nonisolated static func inject(_ asr: InterpretInput) -> String {
        guard !asr.words.isEmpty else { return asr.plainText }
        return inject(words: asr.words)
    }
    nonisolated private static let thresholdSeconds: TimeInterval = 0.45
}
