import Foundation

struct TranscriptSegment: Sendable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

struct TranscriptionOutput: Sendable {
    let text: String
    let segments: [TranscriptSegment]
    let words: [TranscriptWord]
    let language: String?

    nonisolated static var empty: TranscriptionOutput {
        TranscriptionOutput(text: "", segments: [], words: [], language: nil)
    }
}

/// Live caption state surfaced during push-to-talk preview.
struct PartialTranscript: Sendable {
    let confirmedText: String
    let draftText: String
    let lastConfirmedEndSeconds: TimeInterval

    nonisolated static var empty: PartialTranscript {
        PartialTranscript(confirmedText: "", draftText: "", lastConfirmedEndSeconds: 0)
    }
}

enum TranscriptionError: LocalizedError {
    case notReady
    case modelLoadFailed(String)
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notReady: return "The transcription engine is not ready yet."
        case .modelLoadFailed(let m): return "Failed to load the model: \(m)"
        case .transcriptionFailed(let m): return "Transcription failed: \(m)"
        }
    }
}

/// Abstraction over a speech-to-text backend so engines (WhisperKit, Parakeet)
/// can be swapped.
protocol TranscriptionEngine: Sendable {
    func prepare(model: String, downloadBase: URL, progress: @escaping @Sendable (Double) -> Void) async throws
    func transcribe(audioPath: String, language: String?) async throws -> TranscriptionOutput
    func transcribe(samples: [Float], language: String?) async throws -> TranscriptionOutput
    func transcribePartial(
        samples: [Float],
        lastConfirmedEndSeconds: TimeInterval,
        language: String?
    ) async throws -> PartialTranscript
    func resetPartialState() async
    func currentModel() async -> String?
}

enum TranscriptionEngineKind: String, Sendable {
    case whisper
    case parakeet
}

/// Routes dictation to Parakeet (European languages) or WhisperKit (fallback).
enum TranscriptionRouter {
    /// Languages Parakeet v3 does not cover well — route to WhisperKit.
    static let whisperOnlyLanguages: Set<String> = ["ja", "zh", "ko", "hi", "ar"]

    static func engineKind(for model: String, language: String?) -> TranscriptionEngineKind {
        guard ModelManager.isParakeetModel(model) else { return .whisper }
        if let language, whisperOnlyLanguages.contains(language) { return .whisper }
        return .parakeet
    }
}
