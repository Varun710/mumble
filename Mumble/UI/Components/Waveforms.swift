import SwiftUI

/// Live scrolling waveform driven by recent RMS levels (0...1).
struct LiveWaveform: View {
    let levels: [Float]
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1.5, (geo.size.width - CGFloat(count - 1) * spacing) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(color)
                        .frame(width: barWidth, height: max(2, CGFloat(level) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
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
