import Foundation

/// Removes disfluencies / filler words while keeping surrounding text intact.
struct FillerRemover: Sendable {
    nonisolated static let fillers: [String] = [
        "um", "uh", "erm", "er", "ah", "hmm", "uhh", "umm",
        "you know", "i mean", "sort of", "kind of", "like,"
    ]

    nonisolated func removeFillers(from text: String) -> String {
        var result = text
        for filler in Self.fillers {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: filler) + "\\b[,]?"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result
    }

    /// Collapses immediate stutters: "the the cat" -> "the cat", "I I think" -> "I think".
    nonisolated func collapseRepeats(in text: String) -> String {
        let pattern = "\\b(\\w+)(\\s+\\1\\b)+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1")
    }
}
