import Foundation
import SwiftData

/// A single captured recording with its transcript and timestamped segments.
@Model
final class Recording {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    /// Relative file name in the audio directory (see `Paths`). May be empty for dictation-only entries.
    var audioFileName: String
    var language: String?
    var modelName: String?
    var transcript: String
    var notes: String
    /// Origin: "window" for full recordings, "dictation" for push-to-talk captures.
    var source: String
    /// Normalized waveform samples (0...1) for the static player view.
    var waveform: [Float]
    /// User-placed marks (in seconds).
    var marks: [Double]

    @Relationship(deleteRule: .cascade, inverse: \Segment.recording)
    var segments: [Segment]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        duration: TimeInterval = 0,
        audioFileName: String = "",
        language: String? = nil,
        modelName: String? = nil,
        transcript: String = "",
        notes: String = "",
        source: String = "window",
        waveform: [Float] = [],
        marks: [Double] = [],
        segments: [Segment] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.audioFileName = audioFileName
        self.language = language
        self.modelName = modelName
        self.transcript = transcript
        self.notes = notes
        self.source = source
        self.waveform = waveform
        self.marks = marks
        self.segments = segments
    }

    var audioURL: URL? {
        audioFileName.isEmpty ? nil : Paths.audioURL(for: audioFileName)
    }

    var hasAudio: Bool {
        guard let url = audioURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

@MainActor
enum RecordingDeletion {
    static func delete(_ recording: Recording, in context: ModelContext) throws {
        let audioURLs = [recording.audioURL].compactMap { $0 }
        context.delete(recording)
        try context.save()
        try deleteAudioFiles(audioURLs)
    }

    static func delete(_ recordings: [Recording], in context: ModelContext) throws {
        let audioURLs = recordings.compactMap(\.audioURL)
        for recording in recordings {
            context.delete(recording)
        }
        try context.save()
        try deleteAudioFiles(audioURLs)
    }

    private static func deleteAudioFiles(_ urls: [URL]) throws {
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
