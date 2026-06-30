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

    private let engine: any TranscriptionEngine
    private let modelManager: ModelManager

    init(engine: any TranscriptionEngine = WhisperKitEngine(), modelManager: ModelManager) {
        self.engine = engine
        self.modelManager = modelManager
    }

    /// Ensures the configured model is downloaded and loaded.
    func ensureModelLoaded(_ model: String) async throws {
        if loadedModel == model { return }
        status = .loadingModel(0)
        modelManager.setDownloading(model, progress: 0)
        do {
            try await engine.prepare(model: model, downloadBase: Paths.modelsDir) { [weak self] fraction in
                Task { @MainActor in
                    self?.status = .loadingModel(fraction)
                    self?.modelManager.setDownloading(model, progress: fraction)
                }
            }
            loadedModel = model
            modelManager.setReady(model)
            status = .ready
        } catch {
            modelManager.setFailed(model, message: error.localizedDescription)
            status = .error(error.localizedDescription)
            throw error
        }
    }

    func transcribeFile(at url: URL, model: String, language: String?) async throws -> TranscriptionOutput {
        try await ensureModelLoaded(model)
        status = .transcribing
        defer { status = .ready }
        return try await engine.transcribe(audioPath: url.path, language: language)
    }

    func transcribeSamples(_ samples: [Float], model: String, language: String?) async throws -> TranscriptionOutput {
        try await ensureModelLoaded(model)
        status = .transcribing
        defer { status = .ready }
        return try await engine.transcribe(samples: samples, language: language)
    }

    /// Preloads the model in the background (called at launch).
    func warmUp(model: String) {
        Task { try? await ensureModelLoaded(model) }
    }
}
