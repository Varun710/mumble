import OSLog

/// Structured logging for crash diagnosis and runtime breadcrumbs.
enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.mumble.app"

    static let overlay = Logger(subsystem: subsystem, category: "Overlay")
    static let dictation = Logger(subsystem: subsystem, category: "Dictation")
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let transcription = Logger(subsystem: subsystem, category: "Transcription")
    static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
}
