import Foundation

/// Describes when automatic speech recognition is actively running.
enum ASRHomeStatus: Equatable {
    case listening(elapsed: TimeInterval)
    case recording
    case transcribing(modelName: String)

    var title: String {
        switch self {
        case .listening: return "ASR active — listening"
        case .recording: return "ASR active — recording"
        case .transcribing: return "ASR active — transcribing"
        }
    }

    var subtitle: String {
        switch self {
        case .listening(let elapsed):
            let total = max(0, Int(elapsed))
            return "Release \(DictationShortcuts.holdLabel) to transcribe · \(String(format: "%02d:%02d", total / 60, total % 60))"
        case .recording:
            return "Live transcription while you record"
        case .transcribing(let modelName):
            if modelName.isEmpty { return "Running locally on your Mac" }
            return ModelManager.catalog.first { $0.name == modelName }?.displayName ?? modelName
        }
    }
}
