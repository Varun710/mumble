import Foundation
import SwiftData
import Observation
import AppKit

/// Global push-to-talk dictation: hold the **Right Option** key to record,
/// release to transcribe, clean, and paste into the active app. Also supports a
/// tap-to-toggle mode driven from the menu bar.
@MainActor
@Observable
final class DictationController {
    private let transcription: TranscriptionService
    private let settings: SettingsStore
    private let interpreter: Interpreter
    private let permissions: PermissionsService
    private let overlay: OverlayController
    private let container: ModelContainer
    private let paste = PasteService()
    private let monitor = RightOptionMonitor()

    private var pipeline: AudioPipeline?
    private var startedAt: Date?
    private var currentID = UUID()
    private var currentFileURL: URL?
    private(set) var isActive = false
    private(set) var hotkeyActive = false
    /// True while the Right Option key is physically held down.
    private(set) var isHotkeyPressed = false
    private var hideWorkItem: DispatchWorkItem?
    private var levelTask: Task<Void, Never>?
    private var elapsedTimer: Timer?
    private var streamingSession: StreamingTranscriptionSession?
    /// True while `begin()` is still setting up the audio pipeline.
    private var isPreparingRecording = false
    private let maxLevels = 48

    init(transcription: TranscriptionService, settings: SettingsStore, interpreter: Interpreter, permissions: PermissionsService, overlay: OverlayController, container: ModelContainer) {
        self.transcription = transcription
        self.settings = settings
        self.interpreter = interpreter
        self.permissions = permissions
        self.overlay = overlay
        self.container = container
    }

    /// Whether the global Right-Option monitor is currently active.
    var isMonitoring: Bool { hotkeyActive }

    /// Installs (or retries installing) the global Right-Option hold monitor.
    /// Returns false if Input Monitoring permission is missing.
    @discardableResult
    func startMonitoring() -> Bool {
        monitor.onPress = { [weak self] in
            Task { @MainActor in
                self?.isHotkeyPressed = true
                await self?.interpreter.prewarm()
                await self?.begin()
            }
        }
        monitor.onRelease = { [weak self] in
            Task { @MainActor in
                await self?.finish()
                self?.isHotkeyPressed = false
            }
        }
        monitor.onChordCancelled = { [weak self] in
            Task { @MainActor in
                guard let self, self.isActive else { return }
                await self.finish(cancelledByChord: true)
                self.isHotkeyPressed = false
            }
        }
        hotkeyActive = monitor.start()
        return hotkeyActive
    }

    /// Tap-to-toggle: start dictating if idle, otherwise stop + paste.
    /// Used by the menu bar and the optional toggle hotkey.
    func toggle() {
        if isActive {
            Task { await finish() }
        } else {
            Task { await begin() }
        }
    }

    /// Stops the global hotkey monitor and hides the overlay.
    func shutdown() {
        hideWorkItem?.cancel()
        stopElapsedTimer()
        levelTask?.cancel()
        levelTask = nil
        Task { await streamingSession?.cancel() }
        streamingSession = nil
        monitor.stop()
        overlay.hide()
        isActive = false
        hotkeyActive = false
        isHotkeyPressed = false
        pipeline = nil
    }

    private func begin() async {
        guard !isActive, !isPreparingRecording else { return }
        isPreparingRecording = true
        defer { isPreparingRecording = false }
        hideWorkItem?.cancel()
        AppLog.dictation.info("begin")

        guard transcription.isModelDownloaded(settings.modelName) else {
            showError("No speech model yet. Open Mumble ▸ Settings ▸ Models to download one.", hideAfter: 4)
            return
        }

        guard await permissions.requestMicrophone() else {
            showError("Microphone access required. Enable it in System Settings ▸ Privacy ▸ Microphone.", hideAfter: 3)
            return
        }

        let id = UUID()
        currentID = id
        let url = Paths.audioURL(for: Paths.newAudioFileName(id: id))
        currentFileURL = url

        let pipeline = AudioPipeline()
        self.pipeline = pipeline

        overlay.model.phase = .listening
        overlay.model.modelName = settings.modelName
        overlay.model.levels = []
        overlay.model.elapsed = 0
        overlay.model.confirmedCaption = ""
        overlay.model.draftCaption = ""
        overlay.setAppearance(settings.appearance)
        overlay.show()

        let stream: AsyncStream<Float>
        do {
            stream = try await pipeline.startRecording(to: url)
        } catch {
            AppLog.dictation.error("audio start failed: \(error.localizedDescription, privacy: .public)")
            showError(error.localizedDescription, hideAfter: 2.5)
            await pipeline.stop()
            self.pipeline = nil
            return
        }

        isActive = true
        startedAt = Date()
        startElapsedTimer()
        levelTask = Task { [weak self] in
            var lastUpdate = ContinuousClock.now
            for await level in stream {
                let now = ContinuousClock.now
                guard now - lastUpdate >= .milliseconds(66) else { continue }
                lastUpdate = now
                await self?.appendLevel(level)
            }
        }
        startStreamingSession(pipeline: pipeline)
    }

    private func startStreamingSession(pipeline: AudioPipeline) {
        let model = settings.modelName
        let language = settings.language.isEmpty ? nil : settings.language
        let session = StreamingTranscriptionSession(
            transcription: transcription,
            model: model,
            language: language,
            sampleProvider: { await pipeline.pcmSnapshot() },
            onUpdate: { [weak self] (partial: PartialTranscript) in
                Task { @MainActor in
                    guard let self else { return }
                    self.overlay.model.confirmedCaption = partial.confirmedText
                    self.overlay.model.draftCaption = partial.draftText
                    self.overlay.invalidateLayout()
                }
            }
        )
        streamingSession = session
        Task { await session.start() }
    }

    private func finish(cancelledByChord: Bool = false) async {
        while isPreparingRecording {
            try? await Task.sleep(for: .milliseconds(10))
        }
        guard isActive, let pipeline else { return }
        isActive = false
        AppLog.dictation.info("finish")

        stopElapsedTimer()
        levelTask?.cancel()
        levelTask = nil
        overlay.model.levels = []
        overlay.model.confirmedCaption = ""
        overlay.model.draftCaption = ""
        await streamingSession?.cancel()
        streamingSession = nil

        await pipeline.stop()
        self.pipeline = nil

        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        startedAt = nil

        if cancelledByChord {
            if let url = currentFileURL { try? FileManager.default.removeItem(at: url) }
            overlay.hide()
            AppLog.dictation.info("finish cancelled by modifier chord")
            return
        }

        overlay.model.phase = .transcribing
        overlay.show()

        let model = settings.modelName
        let language = settings.language

        guard let url = currentFileURL, FileManager.default.fileExists(atPath: url.path) else {
            showError("Recording failed", hideAfter: 2)
            return
        }

        do {
            let output = try await transcription.transcribeFile(at: url, model: model, language: language)
            let style = settings.resolvedStylePreset(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
            let cleaned = await interpreter.interpret(
                InterpretInput(from: output),
                style: style,
                enabled: settings.interpreterEnabled
            )

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
            AppLog.dictation.info("finish success duration=\(duration, privacy: .public)s")
        } catch {
            AppLog.dictation.error("transcription failed: \(error.localizedDescription, privacy: .public)")
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
        AppLog.dictation.error("error: \(message, privacy: .public)")
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

    private func appendLevel(_ level: Float) {
        overlay.model.levels.append(level)
        if overlay.model.levels.count > maxLevels {
            overlay.model.levels.removeFirst(overlay.model.levels.count - maxLevels)
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let started = self.startedAt else { return }
                self.overlay.model.elapsed = Date().timeIntervalSince(started)
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        overlay.model.elapsed = 0
    }
}
