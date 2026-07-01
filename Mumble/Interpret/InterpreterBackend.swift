import Foundation

enum InterpreterError: Error, Sendable {
    case timeout
    case unavailable
    case backendFailed(String)
}

protocol InterpreterBackend: Sendable {
    func prewarm() async
    func run(input: String, style: StylePreset) async throws -> InterpreterResult
    static var isAvailable: Bool { get }
}

/// No-op backend used when no LLM is available.
struct UnavailableInterpreterBackend: InterpreterBackend {
    static var isAvailable: Bool { false }

    func prewarm() async {}

    func run(input: String, style: StylePreset) async throws -> InterpreterResult {
        throw InterpreterError.unavailable
    }
}
