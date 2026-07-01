import Foundation
import FluidAudio

/// Parakeet TDT ASR via FluidAudio — default for European languages with word timings.
actor ParakeetEngine: TranscriptionEngine {
    nonisolated static let modelID = "parakeet-tdt-v3"

    private var asrManager: AsrManager?
    private var decoderState: TdtDecoderState?
    private var loadedModelName: String?

    func currentModel() async -> String? { loadedModelName }

    func resetPartialState() async {
        guard asrManager != nil else { return }
        decoderState = try? TdtDecoderState()
    }

    func prepare(model: String, downloadBase: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard model == Self.modelID else {
            throw TranscriptionError.modelLoadFailed("Unknown Parakeet model: \(model)")
        }
        if loadedModelName == model, asrManager != nil { return }

        progress(0.1)
        let models = try await AsrModels.downloadAndLoad(to: downloadBase, version: .v3) { downloadProgress in
            progress(0.1 + downloadProgress.fractionCompleted * 0.5)
        }
        progress(0.7)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        asrManager = manager
        decoderState = try TdtDecoderState()
        loadedModelName = model
        progress(1.0)
    }

    func transcribe(audioPath: String, language: String?) async throws -> TranscriptionOutput {
        guard let asrManager else { throw TranscriptionError.notReady }
        guard var state = decoderState else { throw TranscriptionError.notReady }
        let url = URL(fileURLWithPath: audioPath)
        do {
            let fluidLanguage = language.flatMap { Language(rawValue: $0) }
            let result = try await asrManager.transcribe(url, decoderState: &state, language: fluidLanguage)
            decoderState = state
            return Self.map(result, language: language)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    func transcribe(samples: [Float], language: String?) async throws -> TranscriptionOutput {
        guard let asrManager else { throw TranscriptionError.notReady }
        guard !samples.isEmpty else { return .empty }
        guard var state = decoderState else { throw TranscriptionError.notReady }
        do {
            let fluidLanguage = language.flatMap { Language(rawValue: $0) }
            let result = try await asrManager.transcribe(samples, decoderState: &state, language: fluidLanguage)
            decoderState = state
            return Self.map(result, language: language)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    func transcribePartial(
        samples: [Float],
        lastConfirmedEndSeconds: TimeInterval,
        language: String?
    ) async throws -> PartialTranscript {
        let output = try await transcribe(samples: samples, language: language)
        return PartialTranscript(
            confirmedText: output.text,
            draftText: "",
            lastConfirmedEndSeconds: output.segments.last?.end ?? lastConfirmedEndSeconds
        )
    }

    private nonisolated static func map(_ result: ASRResult, language: String?) -> TranscriptionOutput {
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = mapWords(result.tokenTimings)
        let segments: [TranscriptSegment]
        if words.isEmpty {
            segments = text.isEmpty ? [] : [TranscriptSegment(start: 0, end: result.duration, text: text)]
        } else {
            segments = [TranscriptSegment(start: words.first?.start ?? 0, end: words.last?.end ?? result.duration, text: text)]
        }
        return TranscriptionOutput(text: text, segments: segments, words: words, language: language)
    }

    private nonisolated static func mapWords(_ timings: [TokenTiming]?) -> [TranscriptWord] {
        guard let timings else { return [] }
        return timings.compactMap { timing in
            let word = timing.token
                .replacingOccurrences(of: "▁", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty else { return nil }
            return TranscriptWord(text: word, start: timing.startTime, end: timing.endTime)
        }
    }
}
