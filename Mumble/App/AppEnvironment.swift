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
    let interpreter: Interpreter

    /// Set to true to force-present the onboarding flow (e.g. "Run setup again").
    var showOnboarding = false

    init() {
        let container = Persistence.makeContainer()
        let settings = SettingsStore()
        let permissions = PermissionsService()
        let modelManager = ModelManager()
        let transcription = TranscriptionService(modelManager: modelManager)
        let overlay = OverlayController()
        let interpreter = Interpreter(
            backend: InterpreterBackendFactory.make(),
            cleanup: settings.textCleaner,
            snippetExpander: SnippetExpander(store: SnippetStore(entries: settings.snippets))
        )

        self.container = container
        self.settings = settings
        self.permissions = permissions
        self.modelManager = modelManager
        self.transcription = transcription
        self.overlay = overlay
        self.interpreter = interpreter
        self.recorder = RecorderViewModel(
            transcription: transcription,
            settings: settings,
            interpreter: interpreter,
            permissions: permissions,
            container: container
        )
        self.dictation = DictationController(
            transcription: transcription,
            settings: settings,
            interpreter: interpreter,
            permissions: permissions,
            overlay: overlay,
            container: container
        )
    }

    /// Called once after launch.
    func bootstrap() {
        modelManager.refreshAvailability()
        dictation.startMonitoring()

        MenuBarRegistration.prepareForStatusItem()
        MenuBarRegistration.clearStaleStatusItemDefaults()
        menuBar.install(env: self)
        permissions.bind(menuBar: menuBar)

        permissions.refresh()
        MenuBarGuidance.checkAfterLaunch(menuBar: menuBar, permissions: permissions)
        overlay.setAppearance(settings.appearance)

        if case .ready = modelManager.state(for: settings.modelName) {
            transcription.warmUp(model: settings.modelName, language: settings.language)
        }
    }

    /// Tear down background services before app exit.
    func shutdown() {
        dictation.shutdown()
        overlay.hide()
        menuBar.uninstall()
    }

    /// Whether first-run onboarding should be shown.
    var needsOnboarding: Bool {
        !settings.didCompleteOnboarding || showOnboarding
    }

    /// True while dictating, transcribing, or processing a window recording.
    var showsMenuBarActivity: Bool {
        dictation.isActive
            || overlay.model.phase == .transcribing
            || recorder.isRecording
            || recorder.isProcessing
    }

    /// Live speech-recognition activity for the home screen status banner.
    var homeASRStatus: ASRHomeStatus? {
        if dictation.isActive {
            return .listening(elapsed: overlay.model.elapsed)
        }
        if overlay.model.phase == .transcribing {
            return .transcribing(modelName: overlay.model.modelName)
        }
        if recorder.isRecording {
            return .recording
        }
        if recorder.isProcessing || transcription.status.isBusy {
            return .transcribing(modelName: settings.modelName)
        }
        return nil
    }

    let menuBar = MenuBarController()

    func finishOnboarding() {
        settings.didCompleteOnboarding = true
        showOnboarding = false
        // Try to start the global hotkey now that permission may be granted.
        dictation.startMonitoring()
        permissions.refresh()
        if case .ready = modelManager.state(for: settings.modelName) {
            transcription.warmUp(model: settings.modelName, language: settings.language)
        }
    }
}
