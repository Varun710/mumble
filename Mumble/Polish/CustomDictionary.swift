import Foundation

/// Applies user-defined word replacements (case-insensitive, whole-word).
struct CustomDictionary: Sendable {
    let entries: [Replacement]

    struct Replacement: Sendable {
        let from: String
        let to: String
    }

    nonisolated init(entries: [Replacement]) {
        self.entries = entries.filter { !$0.from.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    nonisolated func apply(to text: String) -> String {
        guard !entries.isEmpty else { return text }
        var result = text
        for entry in entries {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: entry.from) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: entry.to)
            )
        }
        return result
    }
}
