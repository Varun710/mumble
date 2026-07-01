import Foundation

struct ASRWord: Sendable, Equatable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval
}

/// Normalized ASR output fed into the Interpreter.
struct InterpretInput: Sendable {
    let plainText: String
    let words: [ASRWord]

    nonisolated init(from output: TranscriptionOutput) {
        plainText = output.text
        words = output.words.map { ASRWord(text: $0.text, start: $0.start, end: $0.end) }
    }

    nonisolated init(plainText: String, words: [ASRWord] = []) {
        self.plainText = plainText
        self.words = words
    }
}
