import Foundation

/// Tidies whitespace and punctuation after filler removal.
struct PunctuationNormalizer: Sendable {
    /// Collapses runs of whitespace, fixes spacing around punctuation.
    nonisolated func normalizeSpacing(_ text: String) -> String {
        var result = text
        result = replace(result, pattern: "[ \\t]{2,}", with: " ")
        result = replace(result, pattern: "\\s+([,.!?;:])", with: "$1")
        result = replace(result, pattern: "([,.!?;:])(?=[^\\s\\d])", with: "$1 ")
        result = replace(result, pattern: " +\\n", with: "\n")
        result = replace(result, pattern: ",\\s*,", with: ",")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Capitalizes sentence starts and ensures a terminal period when punctuation is enabled.
    nonisolated func capitalizeSentences(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var sentences: [String] = []
        let parts = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
        // Re-split keeping delimiters is complex; do a lightweight capitalization pass instead.
        var result = ""
        var capitalizeNext = true
        for char in text {
            if capitalizeNext, char.isLetter {
                result.append(Character(char.uppercased()))
                capitalizeNext = false
            } else {
                result.append(char)
            }
            if char == "." || char == "!" || char == "?" || char == "\n" {
                capitalizeNext = true
            }
        }
        _ = sentences
        _ = parts
        // Ensure terminal punctuation.
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = trimmed.last, !".!?".contains(last) {
            return trimmed + "."
        }
        return trimmed
    }

    private nonisolated func replace(_ text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
