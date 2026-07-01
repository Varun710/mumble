import Foundation

/// Background loop that reads PCM from a recording pipeline and publishes live captions.
actor StreamingTranscriptionSession {
    typealias PublishHandler = @Sendable (PartialTranscript) async -> Void
    typealias SampleProvider = @Sendable () async -> [Float]

    private let transcription: TranscriptionService
    private let model: String
    private let language: String?
    private let sampleProvider: SampleProvider
    private let onUpdate: PublishHandler

    private var task: Task<Void, Never>?
    private var lastPublished = PartialTranscript.empty
    private var lastPublishTime = ContinuousClock.now
    private var lastDecodedSampleCount = 0

    private let minNewAudioSeconds: Float = 1.0
    private let pollInterval: Duration = .milliseconds(200)
    private let publishInterval: Duration = .milliseconds(166)

    init(
        transcription: TranscriptionService,
        model: String,
        language: String?,
        sampleProvider: @escaping SampleProvider,
        onUpdate: @escaping PublishHandler
    ) {
        self.transcription = transcription
        self.model = model
        self.language = language
        self.sampleProvider = sampleProvider
        self.onUpdate = onUpdate
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.run()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func run() async {
        do {
            try await transcription.beginPartialSession(model: model, language: language)
        } catch {
            return
        }

        while !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
            guard !Task.isCancelled else { break }

            let samples = await sampleProvider()
            let newSamples = max(0, samples.count - lastDecodedSampleCount)
            let newSeconds = Float(newSamples) / Float(AudioPipeline.pcmSampleRate)
            guard newSeconds >= minNewAudioSeconds else { continue }
            guard !samples.isEmpty else { continue }

            do {
                let partial = try await transcription.transcribePartial(
                    samples: samples,
                    model: model,
                    language: language
                )
                lastDecodedSampleCount = samples.count
                await publishIfNeeded(partial)
            } catch {
                continue
            }
        }
    }

    private func publishIfNeeded(_ partial: PartialTranscript) async {
        let changed = partial.confirmedText != lastPublished.confirmedText
            || partial.draftText != lastPublished.draftText
        guard changed else { return }
        let now = ContinuousClock.now
        guard now - lastPublishTime >= publishInterval else { return }
        lastPublishTime = now
        lastPublished = partial
        await onUpdate(partial)
    }
}
