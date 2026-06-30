import Foundation
import WhisperKit

/// WhisperKit-backed transcription engine. An actor so the model instance is
/// accessed serially off the main actor.
actor WhisperKitEngine: TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    func currentModel() async -> String? { loadedModelName }

    func prepare(model: String, downloadBase: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        if loadedModelName == model, whisperKit != nil { return }
        do {
            // Download (or locate) the CoreML model, reporting progress.
            let folder = try await WhisperKit.download(
                variant: model,
                downloadBase: downloadBase,
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { p in progress(p.fractionCompleted) }
            )
            // Load + prewarm so the tokenizer is ready before transcription.
            let kit = try await WhisperKit(modelFolder: folder.path, load: true)
            whisperKit = kit
            loadedModelName = model
            progress(1.0)
        } catch {
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }

    func transcribe(audioPath: String, language: String?) async throws -> TranscriptionOutput {
        guard let whisperKit else { throw TranscriptionError.notReady }
        let options = decodingOptions(language: language)
        do {
            let results = try await whisperKit.transcribe(audioPath: audioPath, decodeOptions: options)
            return Self.map(results)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    func transcribe(samples: [Float], language: String?) async throws -> TranscriptionOutput {
        guard let whisperKit else { throw TranscriptionError.notReady }
        guard !samples.isEmpty else { return .empty }
        let options = decodingOptions(language: language)
        do {
            let results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
            return Self.map(results)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func decodingOptions(language: String?) -> DecodingOptions {
        DecodingOptions(
            task: .transcribe,
            language: language,
            wordTimestamps: false,
            chunkingStrategy: .vad
        )
    }

    private nonisolated static func map(_ results: [TranscriptionResult]) -> TranscriptionOutput {
        let text = results
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var segments: [TranscriptSegment] = []
        var language: String?
        for result in results {
            if language == nil { language = result.language }
            for seg in result.segments {
                let cleaned = seg.text.trimmingCharacters(in: .whitespaces)
                guard !cleaned.isEmpty else { continue }
                segments.append(TranscriptSegment(
                    start: TimeInterval(seg.start),
                    end: TimeInterval(seg.end),
                    text: cleaned
                ))
            }
        }
        return TranscriptionOutput(text: text, segments: segments, language: language)
    }
}
