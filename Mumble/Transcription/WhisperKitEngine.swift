import Foundation
import WhisperKit

/// WhisperKit-backed transcription engine. An actor so the model instance is
/// accessed serially off the main actor.
actor WhisperKitEngine: TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private var loadedModelName: String?

    private var lastBufferSize = 0
    private var lastConfirmedSegmentEndSeconds: Float = 0
    private var confirmedSegments: [TranscriptionSegment] = []
    private var unconfirmedSegments: [TranscriptionSegment] = []
    private let requiredSegmentsForConfirmation = 2

    func currentModel() async -> String? { loadedModelName }

    func resetPartialState() {
        lastBufferSize = 0
        lastConfirmedSegmentEndSeconds = 0
        confirmedSegments = []
        unconfirmedSegments = []
    }

    func prepare(model: String, downloadBase: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
        if loadedModelName == model, whisperKit != nil { return }
        do {
            let folder = try await WhisperKit.download(
                variant: model,
                downloadBase: downloadBase,
                from: "argmaxinc/whisperkit-coreml",
                progressCallback: { p in progress(p.fractionCompleted) }
            )
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

    func transcribePartial(
        samples: [Float],
        lastConfirmedEndSeconds: TimeInterval,
        language: String?
    ) async throws -> PartialTranscript {
        guard let whisperKit else { throw TranscriptionError.notReady }
        guard !samples.isEmpty else { return .empty }

        let nextBufferSize = samples.count - lastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)
        guard nextBufferSeconds > 1 else { return currentPartial() }

        lastBufferSize = samples.count

        var options = decodingOptions(language: language)
        options.clipTimestamps = [lastConfirmedSegmentEndSeconds]

        let results: [TranscriptionResult]
        do {
            results = try await whisperKit.transcribe(audioArray: samples, decodeOptions: options)
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }

        let segments = results.flatMap(\.segments)
        if segments.count > requiredSegmentsForConfirmation {
            let numberToConfirm = segments.count - requiredSegmentsForConfirmation
            let confirmedBatch = Array(segments.prefix(numberToConfirm))
            let remaining = Array(segments.suffix(requiredSegmentsForConfirmation))

            if let lastConfirmed = confirmedBatch.last, lastConfirmed.end > lastConfirmedSegmentEndSeconds {
                lastConfirmedSegmentEndSeconds = lastConfirmed.end
                confirmedSegments.append(contentsOf: confirmedBatch)
            }
            unconfirmedSegments = remaining
        } else {
            unconfirmedSegments = segments
        }

        return currentPartial()
    }

    private func currentPartial() -> PartialTranscript {
        let confirmedText = confirmedSegments
            .map { TranscriptDisplayText.sanitize($0.text) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let draftText = unconfirmedSegments
            .map { TranscriptDisplayText.sanitize($0.text) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return PartialTranscript(
            confirmedText: confirmedText,
            draftText: draftText,
            lastConfirmedEndSeconds: TimeInterval(lastConfirmedSegmentEndSeconds)
        )
    }

    private func decodingOptions(language: String?) -> DecodingOptions {
        DecodingOptions(
            task: .transcribe,
            language: language,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: true,
            chunkingStrategy: .vad
        )
    }

    private nonisolated static func map(_ results: [TranscriptionResult]) -> TranscriptionOutput {
        var segments: [TranscriptSegment] = []
        var words: [TranscriptWord] = []
        var language: String?
        for result in results {
            if language == nil { language = result.language }
            for seg in result.segments {
                let cleaned = TranscriptDisplayText.sanitize(seg.text)
                guard !cleaned.isEmpty else { continue }
                segments.append(TranscriptSegment(
                    start: TimeInterval(seg.start),
                    end: TimeInterval(seg.end),
                    text: cleaned
                ))
                if let segWords = seg.words {
                    for timing in segWords {
                        let word = TranscriptDisplayText.sanitize(timing.word)
                        guard !word.isEmpty, !word.hasPrefix("<|") else { continue }
                        words.append(TranscriptWord(
                            text: word,
                            start: TimeInterval(timing.start),
                            end: TimeInterval(timing.end)
                        ))
                    }
                }
            }
        }

        let text = segments
            .map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return TranscriptionOutput(text: text, segments: segments, words: words, language: language)
    }
}
