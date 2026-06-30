import AVFoundation
import Accelerate

/// Computes amplitude data for waveform rendering.
enum WaveformAnalyzer {
    /// RMS level (0...1) of a sample block, with mild gain for visual liveliness.
    nonisolated static func level(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var mean: Float = 0
        vDSP_measqv(samples, 1, &mean, vDSP_Length(samples.count))
        let rms = sqrt(mean)
        return min(1, rms * 6)
    }

    /// Downsamples accumulated 16k samples into `buckets` normalized peaks.
    nonisolated static func buckets(from samples: [Float], buckets: Int) -> [Float] {
        guard !samples.isEmpty, buckets > 0 else { return [] }
        let stride = max(samples.count / buckets, 1)
        var out = [Float](repeating: 0, count: buckets)
        samples.withUnsafeBufferPointer { ptr in
            for b in 0..<buckets {
                let start = b * stride
                guard start < samples.count else { break }
                let count = Swift.min(stride, samples.count - start)
                var peak: Float = 0
                vDSP_maxmgv(ptr.baseAddress! + start, 1, &peak, vDSP_Length(count))
                out[b] = peak
            }
        }
        return normalize(out)
    }

    /// Reads an audio file and downsamples it into `buckets` normalized peaks.
    nonisolated static func buckets(fileURL: URL, buckets: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: fileURL) else { return [] }
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData else { return [] }

        let frames = Int(buffer.frameLength)
        let stride = max(frames / buckets, 1)
        var out = [Float](repeating: 0, count: buckets)
        for b in 0..<buckets {
            let start = b * stride
            guard start < frames else { break }
            let count = Swift.min(stride, frames - start)
            var peak: Float = 0
            vDSP_maxmgv(channel[0] + start, 1, &peak, vDSP_Length(count))
            out[b] = peak
        }
        return normalize(out)
    }

    private nonisolated static func normalize(_ values: [Float]) -> [Float] {
        let maxVal = values.max() ?? 0
        guard maxVal > 0 else { return values }
        return values.map { $0 / maxVal }
    }
}
