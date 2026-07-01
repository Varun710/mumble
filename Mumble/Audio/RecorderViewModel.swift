import Foundation
import SwiftData
import Observation
import AppKit

/// Drives the in-window recording flow: capture -> transcribe -> clean -> persist.
@MainActor
@Observable
final class RecorderViewModel {
    enum Phase: Equatable { case idle, recording, processing }

    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    /// Rolling live levels (0...1) for the record orb / waveform.
    private(set) var levels: [Float] = []
    private(set) var errorMessage: String?
    /// Set when a new recording is persisted, so the UI can navigate to it.
    var lastSavedID: UUID?

    private let transcription: TranscriptionService
    private let settings: SettingsStore
    private let interpreter: Interpreter
    private let permissions: PermissionsService
    private let container: ModelContainer

    private var pipeline: AudioPipeline?
    private var levelTask: Task<Void, Never>?
    private var timer: Timer?
    private var startedAt: Date?
    private var currentID = UUID()
    private var currentFileURL: URL?

    private let maxLevels = 70

    init(transcription: TranscriptionService, settings: SettingsStore, interpreter: Interpreter, permissions: PermissionsService, container: ModelContainer) {
        self.transcription = transcription
        self.settings = settings
        self.interpreter = interpreter
        self.permissions = permissions
        self.container = container
    }

    var isRecording: Bool { phase == .recording }
    var isProcessing: Bool { phase == .processing }

    func toggle() {
        switch phase {
        case .idle: Task { await start() }
        case .recording: Task { await stopAndTranscribe() }
        case .processing: break
        }
    }

    func start() async {
        guard phase == .idle else { return }
        errorMessage = nil

        guard transcription.isModelDownloaded(settings.modelName) else {
            errorMessage = "No speech model downloaded yet. Open Settings → Models to download one."
            return
        }

        guard await permissions.requestMicrophone() else {
            errorMessage = "Microphone access is required. Enable it in System Settings > Privacy & Security > Microphone."
            return
        }

        let id = UUID()
        currentID = id
        let fileName = Paths.newAudioFileName(id: id)
        let url = Paths.audioURL(for: fileName)
        currentFileURL = url

        let pipeline = AudioPipeline()
        self.pipeline = pipeline
        levels = []

        let stream: AsyncStream<Float>
        do {
            stream = try await pipeline.startRecording(to: url)
        } catch {
            errorMessage = error.localizedDescription
            self.pipeline = nil
            return
        }

        phase = .recording
        startedAt = Date()
        startTimer()
        levelTask = Task { [weak self] in
            for await level in stream {
                self?.appendLevel(level)
            }
        }
    }

    func stopAndTranscribe() async {
        guard phase == .recording, let pipeline else { return }
        phase = .processing
        stopTimer()
        levelTask?.cancel()
        levelTask = nil

        await pipeline.stop()
        self.pipeline = nil

        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        startedAt = nil

        let model = settings.modelName
        let language = settings.language
        guard let url = currentFileURL, FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Recording file was not saved."
            phase = .idle
            elapsed = 0
            levels = []
            return
        }

        do {
            let output = try await transcription.transcribeFile(at: url, model: model, language: language)
            save(fileName: url.lastPathComponent, duration: duration, output: output, model: model, language: language)
        } catch {
            errorMessage = error.localizedDescription
        }

        phase = .idle
        elapsed = 0
        levels = []
    }

    func cancel() async {
        guard phase == .recording, let pipeline else { return }
        stopTimer()
        levelTask?.cancel()
        levelTask = nil
        await pipeline.stop()
        self.pipeline = nil
        if let url = currentFileURL { try? FileManager.default.removeItem(at: url) }
        phase = .idle
        elapsed = 0
        levels = []
    }

    private func save(fileName: String, duration: TimeInterval, output: TranscriptionOutput, model: String, language: String) {
        let cleaner = settings.textCleaner
        let style = settings.resolvedStylePreset(bundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        Task { @MainActor in
            let cleaned = await interpreter.interpret(
                InterpretInput(from: output),
                style: style,
                enabled: settings.interpreterEnabled
            )
            await saveRecording(fileName: fileName, duration: duration, output: output, cleaned: cleaned, model: model, language: language, cleaner: cleaner)
        }
    }

    @MainActor
    private func saveRecording(
        fileName: String,
        duration: TimeInterval,
        output: TranscriptionOutput,
        cleaned: String,
        model: String,
        language: String,
        cleaner: TextCleaner
    ) async {
        let waveform = WaveformAnalyzer.buckets(fileURL: Paths.audioURL(for: fileName), buckets: 220)

        let recording = Recording(
            id: currentID,
            title: Self.deriveTitle(from: cleaned),
            duration: duration,
            audioFileName: fileName,
            language: output.language ?? language,
            modelName: model,
            transcript: cleaned,
            source: "window",
            waveform: waveform
        )

        let context = container.mainContext
        context.insert(recording)
        for seg in output.segments {
            let segment = Segment(start: seg.start, end: seg.end, text: cleaner.clean(seg.text))
            segment.recording = recording
            recording.segments.append(segment)
            context.insert(segment)
        }
        try? context.save()
        lastSavedID = recording.id
    }

    static func deriveTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New Recording" }
        let words = trimmed.split(separator: " ").prefix(7).joined(separator: " ")
        return words.count > 60 ? String(words.prefix(60)) + "…" : words
    }

    private func appendLevel(_ level: Float) {
        levels.append(level)
        if levels.count > maxLevels {
            levels.removeFirst(levels.count - maxLevels)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(started)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
