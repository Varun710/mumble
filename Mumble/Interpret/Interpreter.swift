import Foundation
import OSLog

enum InterpreterLog {
    nonisolated static let log = Logger(subsystem: "com.mumble.app", category: "Interpreter")
}

struct Interpreter: Sendable {
    let backend: (any InterpreterBackend)?
    let cleanup: TextCleaner
    let snippetExpander: SnippetExpander
    let timeout: Duration

    nonisolated init(
        backend: (any InterpreterBackend)?,
        cleanup: TextCleaner,
        snippetExpander: SnippetExpander = SnippetExpander(store: SnippetStore(entries: [])),
        timeout: Duration = .milliseconds(600)
    ) {
        self.backend = backend
        self.cleanup = cleanup
        self.snippetExpander = snippetExpander
        self.timeout = timeout
    }

    nonisolated func prewarm() async {
        await backend?.prewarm()
    }

    nonisolated func interpret(_ asr: InterpretInput, style: StylePreset, enabled: Bool) async -> String {
        guard enabled, let backend else {
            return cleanup.clean(asr.plainText)
        }

        let expanded = snippetExpander.expand(asr.plainText)
        let expandedASR = InterpretInput(plainText: expanded, words: asr.words)
        let marked = PauseMarkers.inject(expandedASR)

        do {
            let result = try await withTimeout(timeout) {
                try await backend.run(input: marked, style: style)
            }
            if result.discardAll { return "" }
            guard Guardrail.accept(input: asr.plainText, output: result.text) else {
                InterpreterLog.log.warning("interpreter guardrail rejected output; falling back")
                return cleanup.clean(asr.plainText)
            }
            return result.text
        } catch {
            InterpreterLog.log.warning("interpreter failed (\(String(describing: error))); falling back")
            return cleanup.clean(asr.plainText)
        }
    }
}

private func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: duration)
            throw InterpreterError.timeout
        }
        guard let result = try await group.next() else {
            throw InterpreterError.timeout
        }
        group.cancelAll()
        return result
    }
}
