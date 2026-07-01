import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26, *)
@Generable
struct InterpreterGenerableResult {
    @Guide(description: """
        The final cleaned text to paste. Self-corrections resolved, inline commands executed, \
        filler removed, punctuation/casing fixed. Preserve times, dates, and numeric expressions \
        exactly as dictated (e.g. 2:30 pm). NEVER include meta-commentary, only the text \
        the user wants pasted.
        """)
    var text: String

    @Guide(description: """
        True only if the user said a whole-utterance command like start over / scratch all that \
        meaning discard everything.
        """)
    var discardAll: Bool
}

@available(macOS 26, *)
extension InterpreterGenerableResult {
    var dto: InterpreterResult {
        InterpreterResult(text: text, discardAll: discardAll)
    }
}
#endif

#if canImport(FoundationModels)
@available(macOS 26, *)
final class FoundationModelsBackend: InterpreterBackend, @unchecked Sendable {
    private let session: LanguageModelSession

    init() {
        session = LanguageModelSession(instructions: InterpreterPrompt.system)
    }

    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func prewarm() async {
        session.prewarm(promptPrefix: FoundationModels.Prompt(InterpreterPrompt.cachedPrefix))
    }

    func run(input: String, style: StylePreset) async throws -> InterpreterResult {
        let prompt = InterpreterPrompt.user(input: input, style: style)
        let response = try await session.respond(
            to: prompt,
            generating: InterpreterGenerableResult.self,
            includeSchemaInPrompt: false
        )
        return response.content.dto
    }
}
#endif

enum InterpreterBackendFactory {
    static func make() -> any InterpreterBackend {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), FoundationModelsBackend.isAvailable {
            return FoundationModelsBackend()
        }
        #endif
        if MLXBackend.isAvailable {
            return MLXBackend()
        }
        return UnavailableInterpreterBackend()
    }

    static var isAnyAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), FoundationModelsBackend.isAvailable { return true }
        #endif
        return MLXBackend.isAvailable
    }
}
