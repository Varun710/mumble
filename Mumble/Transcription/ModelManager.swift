import Foundation
import Observation

/// A WhisperKit model the user can choose.
struct ModelInfo: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let displayName: String
    let detail: String
    let approxSize: String
    let recommended: Bool
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
    /// Curated set surfaced in the UI. `name` values match WhisperKit identifiers.
    static let catalog: [ModelInfo] = [
        ModelInfo(name: "base", displayName: "Base", detail: "Fast, lightweight. Good for quick dictation.", approxSize: "~145 MB", recommended: false),
        ModelInfo(name: "base.en", displayName: "Base (English)", detail: "English-only, fastest.", approxSize: "~145 MB", recommended: false),
        ModelInfo(name: "small", displayName: "Small", detail: "Balanced speed and accuracy.", approxSize: "~480 MB", recommended: false),
        ModelInfo(name: "small.en", displayName: "Small (English)", detail: "English-only, balanced.", approxSize: "~480 MB", recommended: false),
        ModelInfo(name: "large-v3-v20240930_turbo", displayName: "Large v3 Turbo", detail: "Best speed/accuracy on Apple Silicon.", approxSize: "~1.5 GB", recommended: true),
        ModelInfo(name: "large-v3-v20240930_626MB", displayName: "Large v3 (Compressed)", detail: "Maximum accuracy, compressed.", approxSize: "~626 MB", recommended: false),
    ]

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
        // WhisperKit stores each model in a subfolder under the download base.
        let candidates = [
            Paths.modelsDir.appendingPathComponent(name),
            Paths.modelsDir.appendingPathComponent("argmaxinc").appendingPathComponent("whisperkit-coreml").appendingPathComponent("openai_whisper-\(name)"),
        ]
        return candidates.contains { url in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        }
    }
}
