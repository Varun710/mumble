import AVFoundation
import Accelerate

/// Owns the AVAudioEngine and microphone tap. Runs off the main actor.
///
/// The real-time tap callback never touches the main actor: a dedicated
/// `TapState` object (only mutated on the audio thread) writes the archive file
/// and yields live RMS levels through a `Sendable` AsyncStream continuation.
/// WhisperKit resamples the saved file internally, so no in-tap conversion is needed.
actor AudioPipeline {
    enum PipelineError: LocalizedError {
        case noInputDevice
        case engineStart(String)

        var errorDescription: String? {
            switch self {
            case .noInputDevice: return "No microphone input device is available."
            case .engineStart(let m): return "Could not start the audio engine: \(m)"
            }
        }
    }

    private let engine = AVAudioEngine()
    private var state: TapState?
    private var levelContinuation: AsyncStream<Float>.Continuation?
    private(set) var isRunning = false

    /// Live RMS levels (0...1). Call before `start`.
    func levelStream() -> AsyncStream<Float> {
        AsyncStream { continuation in
            self.levelContinuation = continuation
        }
    }

    func start(recordingTo fileURL: URL) throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            throw PipelineError.noInputDevice
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: hwFormat.sampleRate,
            AVNumberOfChannelsKey: hwFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let file = try AVAudioFile(forWriting: fileURL, settings: settings)

        let tapState = TapState(file: file, continuation: levelContinuation)
        self.state = tapState

        input.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            nonisolated(unsafe) let buf = buffer
            tapState.process(buf)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            self.state = nil
            throw PipelineError.engineStart(error.localizedDescription)
        }
        isRunning = true
    }

    /// Stops capture and finalizes the archive file.
    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        state?.finish()
        levelContinuation?.finish()
        levelContinuation = nil
        state = nil
        isRunning = false
    }
}

/// Holds the non-Sendable audio file, mutated only on the real-time audio thread.
private nonisolated final class TapState: @unchecked Sendable {
    private var file: AVAudioFile?
    private let continuation: AsyncStream<Float>.Continuation?

    init(file: AVAudioFile?, continuation: AsyncStream<Float>.Continuation?) {
        self.file = file
        self.continuation = continuation
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        if let file {
            try? file.write(from: buffer)
        }
        if let channel = buffer.floatChannelData, buffer.frameLength > 0 {
            var mean: Float = 0
            vDSP_measqv(channel[0], 1, &mean, vDSP_Length(Int(buffer.frameLength)))
            continuation?.yield(min(1, sqrt(mean) * 6))
        }
    }

    func finish() {
        if #available(macOS 15.0, *) {
            file?.close()
        }
        file = nil
    }
}
