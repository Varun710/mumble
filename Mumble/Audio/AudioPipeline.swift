import AVFoundation
import Accelerate

/// Owns the AVAudioEngine and microphone tap. Runs off the main actor.
///
/// The real-time tap callback never touches the main actor: a dedicated
/// `TapState` object (only mutated on the audio thread) writes the archive file,
/// yields live RMS levels, and accumulates 16 kHz mono PCM for streaming STT.
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

    static let pcmSampleRate = 16_000
    /// Cap in-memory PCM at ~60 seconds for long holds.
    static let maxPCMSamples = pcmSampleRate * 60

    private let engine = AVAudioEngine()
    private var state: TapState?
    private var levelContinuation: AsyncStream<Float>.Continuation?
    private(set) var isRunning = false

    /// Starts capture and returns live RMS levels (0...1) in one atomic step so a
    /// concurrent `stop()` cannot slip in between stream setup and engine start.
    func startRecording(to fileURL: URL) throws -> AsyncStream<Float> {
        guard !isRunning else {
            throw PipelineError.engineStart("Audio pipeline is already running.")
        }

        let stream = AsyncStream<Float> { continuation in
            self.levelContinuation = continuation
        }

        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            tearDown()
            throw PipelineError.noInputDevice
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: hwFormat.sampleRate,
            AVNumberOfChannelsKey: hwFormat.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let file = try AVAudioFile(forWriting: fileURL, settings: settings)
            let tapState = TapState(
                file: file,
                continuation: levelContinuation,
                inputSampleRate: hwFormat.sampleRate
            )
            self.state = tapState

            input.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
                nonisolated(unsafe) let buf = buffer
                tapState.process(buf)
            }

            engine.prepare()
            try engine.start()
            isRunning = true
            return stream
        } catch let error as PipelineError {
            tearDown()
            throw error
        } catch {
            tearDown()
            throw PipelineError.engineStart(error.localizedDescription)
        }
    }

    /// Stops capture and finalizes the archive file.
    func stop() {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
        tearDown()
    }

    /// Copy of accumulated 16 kHz mono PCM for streaming decode.
    func pcmSnapshot() -> [Float] {
        state?.pcmSnapshot() ?? []
    }

    func pcmSampleCount() -> Int {
        state?.pcmSampleCount() ?? 0
    }

    private func tearDown() {
        state?.finish()
        state = nil
        levelContinuation?.finish()
        levelContinuation = nil
    }
}

/// Holds the non-Sendable audio file, mutated only on the real-time audio thread.
private nonisolated final class TapState: @unchecked Sendable {
    private var file: AVAudioFile?
    private let continuation: AsyncStream<Float>.Continuation?
    private let inputSampleRate: Double
    private let lock = NSLock()
    private var pcmSamples: [Float] = []
    private var recentEnergy: [Float] = []

    init(
        file: AVAudioFile?,
        continuation: AsyncStream<Float>.Continuation?,
        inputSampleRate: Double
    ) {
        self.file = file
        self.continuation = continuation
        self.inputSampleRate = inputSampleRate
        pcmSamples.reserveCapacity(AudioPipeline.maxPCMSamples)
    }

    func process(_ buffer: AVAudioPCMBuffer) {
        if let file {
            try? file.write(from: buffer)
        }
        if let channel = buffer.floatChannelData, buffer.frameLength > 0 {
            var mean: Float = 0
            vDSP_measqv(channel[0], 1, &mean, vDSP_Length(Int(buffer.frameLength)))
            let level = min(1, sqrt(mean) * 6)
            continuation?.yield(level)
            appendEnergy(level)
        }
        if let converted = convertToPCM(buffer) {
            appendPCMSamples(converted)
        }
    }

    func pcmSnapshot() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return pcmSamples
    }

    func pcmSampleCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return pcmSamples.count
    }

    func recentEnergyLevels() -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        return recentEnergy
    }

    func finish() {
        if #available(macOS 15.0, *) {
            file?.close()
        }
        file = nil
        lock.lock()
        pcmSamples.removeAll(keepingCapacity: false)
        recentEnergy.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    private func appendEnergy(_ level: Float) {
        lock.lock()
        recentEnergy.append(level)
        if recentEnergy.count > 120 {
            recentEnergy.removeFirst(recentEnergy.count - 120)
        }
        lock.unlock()
    }

    private func appendPCMSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        lock.lock()
        pcmSamples.append(contentsOf: samples)
        if pcmSamples.count > AudioPipeline.maxPCMSamples {
            pcmSamples.removeFirst(pcmSamples.count - AudioPipeline.maxPCMSamples)
        }
        lock.unlock()
    }

    private func convertToPCM(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        let inputFrameCount = Int(buffer.frameLength)
        guard inputFrameCount > 0, let inputData = buffer.floatChannelData?[0] else { return nil }

        let ratio = Double(AudioPipeline.pcmSampleRate) / inputSampleRate
        let outputCount = max(1, Int(Double(inputFrameCount) * ratio))
        var output = [Float](repeating: 0, count: outputCount)

        for i in 0..<outputCount {
            let sourceIndex = Double(i) / ratio
            let index = Int(sourceIndex)
            let fraction = Float(sourceIndex - Double(index))
            let sampleA = inputData[min(index, inputFrameCount - 1)]
            let sampleB = inputData[min(index + 1, inputFrameCount - 1)]
            output[i] = sampleA + (sampleB - sampleA) * fraction
        }

        return output
    }
}
