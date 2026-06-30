import Foundation
import AVFoundation
import Observation

/// Audio playback with playhead tracking for the transcript player.
@MainActor
@Observable
final class TranscriptPlayer {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    var rate: Float = 1.0 {
        didSet { applyRate() }
    }

    private var player: AVAudioPlayer?
    private var ticker: Timer?
    private(set) var hasAudio = false

    func load(url: URL?) {
        stop()
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            hasAudio = false
            duration = 0
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.enableRate = true
            player.prepareToPlay()
            self.player = player
            duration = player.duration
            hasAudio = true
        } catch {
            hasAudio = false
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            pause()
        } else {
            player.rate = rate
            player.play()
            isPlaying = true
            startTicker()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTicker()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        stopTicker()
    }

    /// Seek by fraction (0...1).
    func seek(fraction: Double) {
        guard let player else { return }
        let time = max(0, min(duration, duration * fraction))
        player.currentTime = time
        currentTime = time
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(duration, time))
        player.currentTime = clamped
        currentTime = clamped
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    var progress: Double {
        duration > 0 ? currentTime / duration : 0
    }

    private func applyRate() {
        if let player, player.isPlaying { player.rate = rate }
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        if !player.isPlaying {
            isPlaying = false
            stopTicker()
        }
    }
}
