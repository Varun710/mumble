import SwiftUI

/// Live scrolling waveform driven by recent RMS levels (0...1).
struct LiveWaveform: View {
    let levels: [Float]
    var color: Color = Theme.accent
    var gradient: Bool = true
    /// Boost bar height for overlay visibility.
    var amplified: Bool = false

    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 2.5
            let barWidth = max(2, (geo.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    let scaled = amplified ? CGFloat(level) * 2.0 + 0.08 : CGFloat(level)
                    let height = max(amplified ? 4 : 3, min(geo.size.height, scaled * geo.size.height))
                    Capsule()
                        .fill(gradient ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(color))
                        .frame(width: barWidth, height: height)
                        .animation(amplified ? .easeOut(duration: 0.06) : .easeOut(duration: 0.1), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: amplified ? .center : .trailing)
        }
    }
}

/// Logo-style live bars: a few thick pills centered on the midline, like the Mumble mark.
struct LogoLiveWaveform: View {
    let levels: [Float]
    private let barCount = 5

    var body: some View {
        GeometryReader { geo in
            let samples = bucketedLevels()
            HStack(alignment: .center, spacing: 7) {
                ForEach(0..<barCount, id: \.self) { index in
                    let level = samples[index]
                    let amplified = min(1, level * 1.5 + 0.1)
                    let height = max(8, amplified * geo.size.height)
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: 9, height: height)
                        .animation(.easeOut(duration: 0.1), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func bucketedLevels() -> [CGFloat] {
        guard !levels.isEmpty else {
            return [0.18, 0.32, 0.22, 0.28, 0.16]
        }
        let recent = Array(levels.suffix(40))
        let chunk = max(1, recent.count / barCount)
        return (0..<barCount).map { index in
            let start = index * chunk
            let end = min(recent.count, start + chunk)
            guard start < end else { return 0.12 }
            let slice = recent[start..<end]
            let avg = slice.reduce(0, +) / Float(slice.count)
            return CGFloat(avg)
        }
    }
}

/// Static waveform for the transcript player, with a playhead and tap-to-seek.
struct WaveformBars: View {
    let samples: [Float]
    /// Playback progress 0...1.
    var progress: Double = 0
    var height: CGFloat = 64
    var onSeek: ((Double) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let count = max(samples.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1.5, (geo.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    let played = Double(index) / Double(count) <= progress
                    Capsule()
                        .fill(played ? Theme.accent : Theme.textTertiary.opacity(0.5))
                        .frame(width: barWidth, height: max(2, CGFloat(sample) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        onSeek?(Double(fraction))
                    }
            )
        }
        .frame(height: height)
    }
}

/// Placeholder waveform shown when no live data is present (idle orb state).
struct IdleWaveform: View {
    var bars = 28
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars, id: \.self) { i in
                Capsule()
                    .fill(Theme.textTertiary.opacity(0.4))
                    .frame(width: 2, height: CGFloat((i % 5 + 1)) * 3)
            }
        }
    }
}
