import Foundation
import Observation

/// User-facing preferences, persisted to UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    // Recording
    var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }
    var modelName: String {
        didSet { defaults.set(modelName, forKey: Keys.modelName) }
    }
    var autoPunctuation: Bool {
        didSet { defaults.set(autoPunctuation, forKey: Keys.autoPunctuation) }
    }

    // Cleanup pipeline toggles
    var removeFillers: Bool {
        didSet { defaults.set(removeFillers, forKey: Keys.removeFillers) }
    }
    var collapseRepeats: Bool {
        didSet { defaults.set(collapseRepeats, forKey: Keys.collapseRepeats) }
    }
    var normalizeSpacing: Bool {
        didSet { defaults.set(normalizeSpacing, forKey: Keys.normalizeSpacing) }
    }
    var applyDictionary: Bool {
        didSet { defaults.set(applyDictionary, forKey: Keys.applyDictionary) }
    }

    // Dictation output behavior
    var pasteIntoActiveApp: Bool {
        didSet { defaults.set(pasteIntoActiveApp, forKey: Keys.pasteIntoActiveApp) }
    }
    var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: Keys.copyToClipboard) }
    }
    var restoreClipboard: Bool {
        didSet { defaults.set(restoreClipboard, forKey: Keys.restoreClipboard) }
    }

    /// Whether first-run onboarding has been completed.
    var didCompleteOnboarding: Bool {
        didSet { defaults.set(didCompleteOnboarding, forKey: Keys.didCompleteOnboarding) }
    }

    /// UI appearance: system, light, or dark.
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    /// Custom dictionary as "wrong=>right" replacement pairs plus protected spellings.
    var dictionaryEntries: [DictionaryEntry] {
        didSet { persistDictionary() }
    }

    // Intelligence / Interpreter
    var interpreterEnabled: Bool {
        didSet { defaults.set(interpreterEnabled, forKey: Keys.interpreterEnabled) }
    }
    var stylePreset: StylePreset {
        didSet { defaults.set(stylePreset.rawValue, forKey: Keys.stylePreset) }
    }
    var autoStyleByApp: Bool {
        didSet { defaults.set(autoStyleByApp, forKey: Keys.autoStyleByApp) }
    }
    var snippets: [Snippet] {
        didSet { persistSnippets() }
    }

    private let defaults: UserDefaults
    private static let legacyDefaultsDomain = "com.mumble.app"
    private static let migrationKey = "settings.migratedLegacyDefaults"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateLegacyDefaultsIfNeeded(into: defaults)
        self.language = defaults.string(forKey: Keys.language) ?? "en"
        self.modelName = defaults.string(forKey: Keys.modelName) ?? Self.defaultModel
        self.autoPunctuation = defaults.object(forKey: Keys.autoPunctuation) as? Bool ?? true
        self.removeFillers = defaults.object(forKey: Keys.removeFillers) as? Bool ?? true
        self.collapseRepeats = defaults.object(forKey: Keys.collapseRepeats) as? Bool ?? true
        self.normalizeSpacing = defaults.object(forKey: Keys.normalizeSpacing) as? Bool ?? true
        self.applyDictionary = defaults.object(forKey: Keys.applyDictionary) as? Bool ?? true
        self.pasteIntoActiveApp = defaults.object(forKey: Keys.pasteIntoActiveApp) as? Bool ?? true
        self.copyToClipboard = defaults.object(forKey: Keys.copyToClipboard) as? Bool ?? true
        self.restoreClipboard = defaults.object(forKey: Keys.restoreClipboard) as? Bool ?? true
        self.didCompleteOnboarding = defaults.object(forKey: Keys.didCompleteOnboarding) as? Bool ?? false
        self.appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system

        if let data = defaults.data(forKey: Keys.dictionary),
           let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            self.dictionaryEntries = decoded
        } else {
            self.dictionaryEntries = []
        }

        self.interpreterEnabled = defaults.object(forKey: Keys.interpreterEnabled) as? Bool ?? false
        self.stylePreset = StylePreset(rawValue: defaults.string(forKey: Keys.stylePreset) ?? "") ?? .neutral
        self.autoStyleByApp = defaults.object(forKey: Keys.autoStyleByApp) as? Bool ?? true
        if let data = defaults.data(forKey: Keys.snippets),
           let decoded = try? JSONDecoder().decode([Snippet].self, from: data) {
            self.snippets = decoded
        } else {
            self.snippets = []
        }
    }

    static let defaultModel = "base"

    private static func migrateLegacyDefaultsIfNeeded(into defaults: UserDefaults) {
        guard !defaults.bool(forKey: migrationKey),
              let legacy = UserDefaults.standard.persistentDomain(forName: legacyDefaultsDomain) else { return }
        for (key, value) in legacy where key.hasPrefix("settings.") {
            defaults.set(value, forKey: key)
        }
        defaults.set(true, forKey: migrationKey)
    }

    private func persistDictionary() {
        if let data = try? JSONEncoder().encode(dictionaryEntries) {
            defaults.set(data, forKey: Keys.dictionary)
        }
    }

    private func persistSnippets() {
        if let data = try? JSONEncoder().encode(snippets) {
            defaults.set(data, forKey: Keys.snippets)
        }
    }

    /// Resolves the active style preset (manual or auto by frontmost app).
    func resolvedStylePreset(bundleID: String?) -> StylePreset {
        if autoStyleByApp {
            return AppContextRouter().preset(forFrontmostBundleID: bundleID)
        }
        return stylePreset
    }

    var interpreter: Interpreter {
        Interpreter(
            backend: InterpreterBackendFactory.make(),
            cleanup: textCleaner,
            snippetExpander: SnippetExpander(store: SnippetStore(entries: snippets))
        )
    }

    /// Rebuilds the interpreter when snippets change (called from settings UI if needed).
    func makeInterpreter() -> Interpreter {
        interpreter
    }

    private enum Keys {
        static let language = "settings.language"
        static let modelName = "settings.modelName"
        static let autoPunctuation = "settings.autoPunctuation"
        static let removeFillers = "settings.removeFillers"
        static let collapseRepeats = "settings.collapseRepeats"
        static let normalizeSpacing = "settings.normalizeSpacing"
        static let applyDictionary = "settings.applyDictionary"
        static let pasteIntoActiveApp = "settings.pasteIntoActiveApp"
        static let copyToClipboard = "settings.copyToClipboard"
        static let restoreClipboard = "settings.restoreClipboard"
        static let didCompleteOnboarding = "settings.didCompleteOnboarding"
        static let appearance = "settings.appearance"
        static let dictionary = "settings.dictionary"
        static let interpreterEnabled = "settings.interpreterEnabled"
        static let stylePreset = "settings.stylePreset"
        static let autoStyleByApp = "settings.autoStyleByApp"
        static let snippets = "settings.snippets"
    }
}

struct DictionaryEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// Spoken/incorrect form (case-insensitive match).
    var from: String
    /// Desired replacement spelling.
    var to: String
}

/// Supported transcription languages surfaced in the UI.
struct LanguageOption: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let name: String

    static let all: [LanguageOption] = [
        .init(code: "en", name: "English (US)"),
        .init(code: "es", name: "Spanish"),
        .init(code: "fr", name: "French"),
        .init(code: "de", name: "German"),
        .init(code: "it", name: "Italian"),
        .init(code: "pt", name: "Portuguese"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "zh", name: "Chinese"),
        .init(code: "ko", name: "Korean"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "ru", name: "Russian"),
    ]

    static func name(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code.uppercased()
    }
}
