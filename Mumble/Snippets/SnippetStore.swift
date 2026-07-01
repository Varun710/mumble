import Foundation

struct Snippet: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var trigger: String
    var expansion: String
}

/// Persisted voice snippet triggers (trigger phrase → expansion text).
struct SnippetStore: Sendable {
    let entries: [Snippet]

    nonisolated init(entries: [Snippet]) {
        self.entries = entries
    }

    nonisolated var lookup: [String: String] {
        Dictionary(
            uniqueKeysWithValues: entries.compactMap { snippet in
                let key = Self.normalize(snippet.trigger)
                guard !key.isEmpty, !snippet.expansion.isEmpty else { return nil }
                return (key, snippet.expansion)
            }
        )
    }

    nonisolated static func normalize(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct SnippetExpander: Sendable {
    let store: SnippetStore

    nonisolated func expand(_ text: String) -> String {
        let lookup = store.lookup
        guard !lookup.isEmpty else { return text }

        let normalized = SnippetStore.normalize(text)
        for (trigger, expansion) in lookup {
            guard normalized.contains(trigger) else { continue }
            // Whole-phrase replacement on the original casing.
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: trigger) + "\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: NSRegularExpression.escapedTemplate(for: expansion)
            )
        }
        return text
    }
}
