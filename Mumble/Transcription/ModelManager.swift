import Foundation
import Observation
import WhisperKit

/// A WhisperKit model the user can choose.
struct ModelInfo: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let detail: String
    let approxSize: String
    let recommended: Bool
    let engine: TranscriptionEngineKind
}

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(Double)
    case ready
    case failed(String)
}

/// Curated model catalog plus per-model download/availability state.
@MainActor
@Observable
final class ModelManager {
    /// Curated set surfaced in the UI. `name` values match WhisperKit identifiers or Parakeet IDs.
    static let catalog: [ModelInfo] = [
        ModelInfo(name: ParakeetEngine.modelID, displayName: "Parakeet TDT v3", detail: "Fast English/European dictation with word timings.", approxSize: "~600 MB", recommended: true, engine: .parakeet),
        ModelInfo(name: "base", displayName: "Base", detail: "Fast, lightweight. Good for quick dictation.", approxSize: "~145 MB", recommended: false, engine: .whisper),
        ModelInfo(name: "base.en", displayName: "Base (English)", detail: "English-only, fastest.", approxSize: "~145 MB", recommended: false, engine: .whisper),
        ModelInfo(name: "small", displayName: "Small", detail: "Balanced speed and accuracy.", approxSize: "~480 MB", recommended: false, engine: .whisper),
        ModelInfo(name: "small.en", displayName: "Small (English)", detail: "English-only, balanced.", approxSize: "~480 MB", recommended: false, engine: .whisper),
        ModelInfo(name: "large-v3-v20240930_turbo", displayName: "Large v3 Turbo", detail: "Best speed/accuracy on Apple Silicon.", approxSize: "~1.5 GB", recommended: false, engine: .whisper),
        ModelInfo(name: "large-v3-v20240930_626MB", displayName: "Large v3 (Compressed)", detail: "Maximum accuracy, compressed.", approxSize: "~626 MB", recommended: false, engine: .whisper),
    ]

    static func isParakeetModel(_ name: String) -> Bool {
        name == ParakeetEngine.modelID
    }

    private static let parakeetReadyKey = "models.parakeet.ready"

    static func engineKind(for name: String) -> TranscriptionEngineKind {
        catalog.first { $0.name == name }?.engine ?? .whisper
    }

    var states: [String: ModelDownloadState] = [:]

    init() {
        refreshAvailability()
    }

    func info(for name: String) -> ModelInfo? {
        Self.catalog.first { $0.name == name }
    }

    func displayName(for name: String) -> String {
        info(for: name)?.displayName ?? name
    }

    func state(for name: String) -> ModelDownloadState {
        states[name] ?? .notDownloaded
    }

    func isReady(_ name: String) -> Bool {
        if case .ready = state(for: name) { return true }
        return false
    }

    var hasAnyDownloadedModel: Bool {
        Self.catalog.contains { isReady($0.name) }
    }

    var isAnyDownloading: Bool {
        states.values.contains { if case .downloading = $0 { return true } else { return false } }
    }

    /// Starts a download for `name`. Multiple downloads can run concurrently;
    /// each updates its own per-model progress. No-op if ready or already downloading.
    func download(_ name: String) {
        switch state(for: name) {
        case .ready, .downloading: return
        default: break
        }
        states[name] = .downloading(0)
        Task {
            do {
                if Self.isParakeetModel(name) {
                    let engine = ParakeetEngine()
                    try await engine.prepare(model: name, downloadBase: Paths.modelsDir) { progress in
                        Task { @MainActor in
                            if case .downloading = self.states[name] {
                                self.states[name] = .downloading(progress)
                            }
                        }
                    }
                } else {
                    _ = try await WhisperKit.download(
                        variant: name,
                        downloadBase: Paths.modelsDir,
                        from: "argmaxinc/whisperkit-coreml",
                        progressCallback: { progress in
                            Task { @MainActor in
                                if case .downloading = self.states[name] {
                                    self.states[name] = .downloading(progress.fractionCompleted)
                                }
                            }
                        }
                    )
                }
                self.states[name] = .ready
                if Self.isParakeetModel(name) {
                    UserDefaults.standard.set(true, forKey: Self.parakeetReadyKey)
                }
            } catch {
                self.states[name] = .failed(error.localizedDescription)
            }
        }
    }

    /// Marks models already present in the local cache as ready.
    func refreshAvailability() {
        let fm = FileManager.default
        for model in Self.catalog {
            if isDownloaded(model.name, fm: fm) {
                states[model.name] = .ready
            } else if states[model.name] == nil {
                states[model.name] = .notDownloaded
            }
        }
    }

    func setDownloading(_ name: String, progress: Double) {
        states[name] = .downloading(progress)
    }

    func setReady(_ name: String) {
        states[name] = .ready
    }

    func setFailed(_ name: String, message: String) {
        states[name] = .failed(message)
    }

    private func isDownloaded(_ name: String, fm: FileManager) -> Bool {
        if Self.isParakeetModel(name) {
            return UserDefaults.standard.bool(forKey: Self.parakeetReadyKey)
        }
        // WhisperKit stores each model in a folder like "openai_whisper-<variant>"
        // somewhere under the download base. Search for it (and require it to be non-empty).
        let folderNames: Set<String> = ["openai_whisper-\(name)", name]
        guard let enumerator = fm.enumerator(
            at: Paths.modelsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        for case let url as URL in enumerator {
            guard folderNames.contains(url.lastPathComponent) else { continue }
            let contents = (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
            if !contents.isEmpty { return true }
        }
        return false
    }
}
