import Foundation

/// Lightweight display filter for WhisperKit segment text — strips metadata
/// that can leak into live captions without running the full `TextCleaner` pipeline.
nonisolated enum TranscriptDisplayText {
    private static let timestampRange = try! NSRegularExpression(
        pattern: #"\[\s*\d+(?:\.\d+)?\s*-->\s*\d+(?:\.\d+)?\s*\]"#,
        options: .caseInsensitive
    )
    private static let angleTokens = try! NSRegularExpression(
        pattern: #"<\|[^|]*\|>"#,
        options: []
    )
    private static let metadataPhrases = [
        "start of transcript",
        "end of transcript",
        "end of text",
    ]

    static func sanitize(_ raw: String) -> String {
        var text = raw

        text = timestampRange.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
        text = angleTokens.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )

        for phrase in metadataPhrases {
            text = text.replacingOccurrences(
                of: phrase,
                with: "",
                options: .caseInsensitive
            )
        }

        return text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
