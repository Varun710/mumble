import Foundation

/// Typed output from the Interpreter LLM pass.
struct InterpreterResult: Codable, Sendable, Equatable {
    var text: String
    var discardAll: Bool

    nonisolated init(text: String, discardAll: Bool = false) {
        self.text = text
        self.discardAll = discardAll
    }
}
