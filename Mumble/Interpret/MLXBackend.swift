import Foundation

/// MLX-Swift fallback interpreter for macOS without Apple Intelligence.
final class MLXBackend: InterpreterBackend, @unchecked Sendable {
    static var isAvailable: Bool {
        MLXInterpreterRunner.isModelReady
    }

    func prewarm() async {
        await MLXInterpreterRunner.shared.prewarm()
    }

    func run(input: String, style: StylePreset) async throws -> InterpreterResult {
        try await MLXInterpreterRunner.shared.run(input: input, style: style)
    }
}
