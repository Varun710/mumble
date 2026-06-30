import Foundation
import SwiftData
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Hold to dictate, release to transcribe + paste.
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: [.control, .option]))
}

/// Global push-to-talk dictation: hold the hotkey to record, release to
/// transcribe, clean, and paste into the active app.
@MainActor
final class DictationController {
    private let transcription: TranscriptionService
    private let settings: SettingsStore
    private let permissions: PermissionsService
    private let overlay: OverlayController
    private let container: ModelContainer
    private let paste = PasteService()

    private var pipeline: AudioPipeline?
    private var levelTask: Task<Void, Never>?
    private var timer: Timer?
    private var startedAt: Date?
    private var currentID = UUID()
    private var currentFileURL: URL?
    private var isActive = false
    private var hideWorkItem: DispatchWorkItem?

    init(transcription: TranscriptionService, settings: SettingsStore, permissions: PermissionsService, overlay: OverlayController, container: ModelContainer) {
        self.transcription = transcription
        self.settings = settings
        self.permissions = permissions
        self.overlay = overlay
        self.container = container
    }

    func registerHotkey() {
        KeyboardShortcuts.onKeyDown(for: .pushToTalk) { [weak self] in
            Task { await self?.begin() }
        }
        KeyboardShortcuts.onKeyUp(for: .pushToTalk) { [weak self] in
            Task { await self?.finish() }
        }
    }

    private func begin() async {
        guard !isActive else { return }
        isActive = true
        hideWorkItem?.cancel()

        guard await permissions.requestMicrophone() else {
            showError("Microphone access required", hideAfter: 2.5)
            isActive = false
            return
        }

        let id = UUID()
        currentID = id
        let url = Paths.audioURL(for: Paths.newAudioFileName(id: id))
        currentFileURL = url

        let pipeline = AudioPipeline()
        self.pipeline = pipeline

        overlay.model.phase = .listening
        overlay.model.levels = []
        overlay.model.elapsed = 0
        overlay.model.modelName = settings.modelName

        let stream = await pipeline.levelStream()
        do {
            try await pipeline.start(recordingTo: url)
        } catch {
            showError(error.localizedDescription, hideAfter: 2.5)
            self.pipeline = nil
            isActive = false
            return
        }

        overlay.show()
        startedAt = Date()
        startTimer()
        levelTask = Task { [weak self] in
            for await level in stream {
                guard let self else { return }
                var levels = self.overlay.model.levels
                levels.append(level)
                if levels.count > 60 { levels.removeFirst(levels.count - 60) }
                self.overlay.model.levels = levels
            }
        }
    }

    private func finish() async {
        guard isActive, let pipeline else { return }
        isActive = false
        stopTimer()
        levelTask?.cancel()
        levelTask = nil

        overlay.model.phase = .transcribing
        await pipeline.stop()
        self.pipeline = nil

        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        startedAt = nil

        let model = settings.modelName
        let language = settings.language

        guard let url = currentFileURL, FileManager.default.fileExists(atPath: url.path) else {
            showError("Recording failed", hideAfter: 2)
            return
        }

        do {
            let output = try await transcription.transcribeFile(at: url, model: model, language: language)
            let cleaned = settings.textCleaner.clean(output.text)

            if cleaned.isEmpty {
                showError("No speech detected", hideAfter: 1.5)
                try? FileManager.default.removeItem(at: url)
                return
            }

            deliver(cleaned)
            overlay.model.phase = .done
            overlay.show()
            scheduleHide(after: 0.9)
            save(duration: duration, output: output, cleaned: cleaned, model: model, language: language)
        } catch {
            showError(error.localizedDescription, hideAfter: 2.5)
        }
    }

    private func deliver(_ text: String) {
        if settings.pasteIntoActiveApp {
            // Accessibility (PostEvent) is required; if missing, still copy so the
            // user can paste manually.
            if permissions.accessibility != .granted {
                permissions.requestAccessibility(prompt: true)
            }
            paste.paste(text, copyToClipboard: settings.copyToClipboard, restoreClipboard: settings.restoreClipboard)
        } else if settings.copyToClipboard {
            ClipboardService().copy(text)
        }
    }

    private func save(duration: TimeInterval, output: TranscriptionOutput, cleaned: String, model: String, language: String) {
        let waveform = WaveformAnalyzer.buckets(fileURL: currentFileURL ?? Paths.audioDir, buckets: 180)
        let recording = Recording(
            id: currentID,
            title: RecorderViewModel.deriveTitle(from: cleaned),
            duration: duration,
            audioFileName: currentFileURL?.lastPathComponent ?? "",
            language: output.language ?? language,
            modelName: model,
            transcript: cleaned,
            source: "dictation",
            waveform: waveform
        )
        let context = container.mainContext
        context.insert(recording)
        for seg in output.segments {
            let segment = Segment(start: seg.start, end: seg.end, text: settings.textCleaner.clean(seg.text))
            segment.recording = recording
            recording.segments.append(segment)
            context.insert(segment)
        }
        try? context.save()
    }

    // MARK: - Overlay helpers

    private func showError(_ message: String, hideAfter: TimeInterval) {
        overlay.model.phase = .error
        overlay.model.message = message
        overlay.show()
        scheduleHide(after: hideAfter)
    }

    private func scheduleHide(after seconds: TimeInterval) {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.overlay.hide() }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.startedAt else { return }
                self.overlay.model.elapsed = Date().timeIntervalSince(started)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
