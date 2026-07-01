import Foundation
import Observation

enum EngineStatus: Equatable {
    case idle
    case loadingModel(Double)
    case ready
    case transcribing
    case error(String)

    var label: String {
        switch self {
        case .idle: return "Idle"
        case .loadingModel(let p): return "Loading \(Int(p * 100))%"
        case .ready: return "Running"
        case .transcribing: return "Transcribing"
        case .error: return "Error"
        }
    }

    var isBusy: Bool {
        switch self {
        case .loadingModel, .transcribing: return true
        default: return false
        }
    }
}

/// Orchestrates model loading + transcription and publishes engine status to the UI.
@MainActor
@Observable
final class TranscriptionService {
    private(set) var status: EngineStatus = .idle
    private(set) var loadedModel: String?

    private let whisperEngine: WhisperKitEngine
    private let parakeetEngine: ParakeetEngine
    private let modelManager: ModelManager
    private var activeEngineKind: TranscriptionEngineKind?

    init(
        whisperEngine: WhisperKitEngine = WhisperKitEngine(),
        parakeetEngine: ParakeetEngine = ParakeetEngine(),
        modelManager: ModelManager
    ) {
        self.whisperEngine = whisperEngine
        self.parakeetEngine = parakeetEngine
        self.modelManager = modelManager
    }

    /// Whether the given model has been downloaded and is ready to use.
    func isModelDownloaded(_ model: String) -> Bool {
        modelManager.isReady(model)
    }

    private func engine(for model: String, language: String?) -> any TranscriptionEngine {
        switch TranscriptionRouter.engineKind(for: model, language: language) {
        case .parakeet: return parakeetEngine
        case .whisper: return whisperEngine
        }
    }

    /// Ensures the configured model is loaded into the engine for transcription.
    func ensureModelLoaded(_ model: String, language: String?) async throws {
        let kind = TranscriptionRouter.engineKind(for: model, language: language)
        let engine = engine(for: model, language: language)

        if loadedModel == model, activeEngineKind == kind { return }

        status = .loadingModel(0)
        do {
            try await engine.prepare(model: model, downloadBase: Paths.modelsDir) { [weak self] fraction in
                Task { @MainActor in
                    self?.status = .loadingModel(fraction)
                }
            }
            loadedModel = model
            activeEngineKind = kind
            modelManager.setReady(model)
            status = .ready
        } catch {
            status = .error(error.localizedDescription)
            throw error
        }
    }

    func transcribeFile(at url: URL, model: String, language: String?) async throws -> TranscriptionOutput {
        try await ensureModelLoaded(model, language: language)
        status = .transcribing
        defer { status = .ready }
        let engine = engine(for: model, language: language)
        return try await engine.transcribe(audioPath: url.path, language: language)
    }

    func transcribeSamples(_ samples: [Float], model: String, language: String?) async throws -> TranscriptionOutput {
        try await ensureModelLoaded(model, language: language)
        status = .transcribing
        defer { status = .ready }
        let engine = engine(for: model, language: language)
        return try await engine.transcribe(samples: samples, language: language)
    }

    /// Resets streaming decode state at the start of a dictation hold.
    func beginPartialSession(model: String, language: String?) async throws {
        try await ensureModelLoaded(model, language: language)
        let engine = engine(for: model, language: language)
        await engine.resetPartialState()
    }

    /// Incremental decode for live caption preview.
    func transcribePartial(
        samples: [Float],
        model: String,
        language: String?
    ) async throws -> PartialTranscript {
        let engine = engine(for: model, language: language)
        return try await engine.transcribePartial(
            samples: samples,
            lastConfirmedEndSeconds: 0,
            language: language
        )
    }

    /// Preloads the model in the background (called at launch).
    func warmUp(model: String, language: String? = nil) {
        Task { try? await ensureModelLoaded(model, language: language) }
    }

}
