import Foundation

/// Deterministic "raw transcript -> polished dictation" pipeline.
/// Pure value type so it can run off the main actor.
struct TextCleaner: Sendable {
    struct Options: Sendable {
        var removeFillers: Bool
        var collapseRepeats: Bool
        var normalizeSpacing: Bool
        var autoPunctuation: Bool
        var applyDictionary: Bool
        var dictionary: [CustomDictionary.Replacement]
    }

    let options: Options

    private let fillerRemover = FillerRemover()
    private let punctuation = PunctuationNormalizer()

    nonisolated func clean(_ raw: String) -> String {
        var text = raw

        if options.applyDictionary {
            text = CustomDictionary(entries: options.dictionary).apply(to: text)
        }
        if options.removeFillers {
            text = fillerRemover.removeFillers(from: text)
        }
        if options.collapseRepeats {
            text = fillerRemover.collapseRepeats(in: text)
        }
        if options.normalizeSpacing {
            text = punctuation.normalizeSpacing(text)
        }
        if options.autoPunctuation {
            text = punctuation.capitalizeSentences(text)
        } else if options.normalizeSpacing {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }
}

extension SettingsStore {
    /// Builds a cleaner reflecting the current cleanup preferences.
    var textCleaner: TextCleaner {
        TextCleaner(options: .init(
            removeFillers: removeFillers,
            collapseRepeats: collapseRepeats,
            normalizeSpacing: normalizeSpacing,
            autoPunctuation: autoPunctuation,
            applyDictionary: applyDictionary,
            dictionary: dictionaryEntries.map { .init(from: $0.from, to: $0.to) }
        ))
    }
}
