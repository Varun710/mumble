import Foundation

/// Runs constrained JSON generation via MLX when Foundation Models is unavailable.
///
/// Wire `mlx-swift-lm` + `mlx-swift-structured` packages in `project.yml` and
/// implement `ensureLoaded()` to activate this fallback path.
enum MLXInterpreterRunner {
    static var isModelReady: Bool { shared.isReady }

    static let shared = Runner()

    final class Runner: @unchecked Sendable {
        private(set) var isReady = false

        func prewarm() async {}

        func run(input: String, style: StylePreset) async throws -> InterpreterResult {
            guard isReady else { throw InterpreterError.unavailable }
            throw InterpreterError.unavailable
        }

        func markReady() {
            isReady = true
        }
    }
}
