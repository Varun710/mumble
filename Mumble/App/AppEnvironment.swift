import Foundation
import SwiftData
import Observation

/// Root dependency container shared across the app via the SwiftUI environment.
@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let settings: SettingsStore
    let permissions: PermissionsService
    let modelManager: ModelManager
    let transcription: TranscriptionService
    let recorder: RecorderViewModel
    let dictation: DictationController
    let overlay: OverlayController

    init() {
        let container = Persistence.makeContainer()
        let settings = SettingsStore()
        let permissions = PermissionsService()
        let modelManager = ModelManager()
        let transcription = TranscriptionService(modelManager: modelManager)
        let overlay = OverlayController()

        self.container = container
        self.settings = settings
        self.permissions = permissions
        self.modelManager = modelManager
        self.transcription = transcription
        self.overlay = overlay
        self.recorder = RecorderViewModel(
            transcription: transcription,
            settings: settings,
            permissions: permissions,
            container: container
        )
        self.dictation = DictationController(
            transcription: transcription,
            settings: settings,
            permissions: permissions,
            overlay: overlay,
            container: container
        )
    }

    /// Called once after launch.
    func bootstrap() {
        permissions.refresh()
        modelManager.refreshAvailability()
        dictation.registerHotkey()

        if case .ready = modelManager.state(for: settings.modelName) {
            transcription.warmUp(model: settings.modelName)
        }
    }

}
