import Foundation

/// On-disk layout under ~/Library/Application Support/<bundle id>/.
/// Only relative file names are stored in the DB; absolute URLs are rebuilt here.
nonisolated enum Paths {
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "com.mumble.app" }

    static var root: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent(bundleID, isDirectory: true)
        ensure(dir)
        return dir
    }

    static var databaseDir: URL { sub("db") }
    static var audioDir: URL { sub("audio") }
    static var modelsDir: URL { sub("models") }

    static var databaseFile: URL { databaseDir.appendingPathComponent("mumble.store") }

    /// Absolute URL for a stored audio file name.
    static func audioURL(for fileName: String) -> URL {
        audioDir.appendingPathComponent(fileName)
    }

    static func newAudioFileName(id: UUID) -> String { "\(id.uuidString).m4a" }

    private static func sub(_ name: String) -> URL {
        let dir = root.appendingPathComponent(name, isDirectory: true)
        ensure(dir)
        return dir
    }

    private static func ensure(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
