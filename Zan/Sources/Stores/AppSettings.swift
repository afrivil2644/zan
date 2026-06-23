import Foundation
import Combine

/// Scalar app settings, persisted in UserDefaults. The API key is NOT here:
/// it goes to the Keychain (wired in Stage 3).
@MainActor
final class AppSettings: ObservableObject {
    @Published var transcriptionModel: String {
        didSet { defaults.set(transcriptionModel, forKey: Keys.transcriptionModel) }
    }
    @Published var textModel: String {
        didSet { defaults.set(textModel, forKey: Keys.textModel) }
    }
    @Published var cleanupEnabled: Bool {
        didSet { defaults.set(cleanupEnabled, forKey: Keys.cleanupEnabled) }
    }
    /// Dictation trigger behavior: toggle (press to start/stop) or hold-to-talk.
    @Published var dictationMode: DictationMode {
        didSet { defaults.set(dictationMode.rawValue, forKey: Keys.dictationMode) }
    }
    @Published var transcriptLogPath: String {
        didSet { defaults.set(transcriptLogPath, forKey: Keys.transcriptLogPath) }
    }
    /// Show the app window automatically on launch (so it isn't invisible).
    @Published var openWindowOnLaunch: Bool {
        didSet { defaults.set(openWindowOnLaunch, forKey: Keys.openWindowOnLaunch) }
    }

    // Quick-pick presets. The fields are free-text too, so any model ID (incl.
    // ones newer than this list) can be typed in directly.
    static let transcriptionModels = ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
    static let textModels = ["gpt-4o-mini", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1", "gpt-4o"]

    enum DictationMode: String, CaseIterable, Identifiable {
        case toggle, holdToTalk
        var id: String { rawValue }
        var label: String { self == .toggle ? "Toggle (press to start/stop)" : "Hold to talk" }
    }

    private let defaults = UserDefaults.standard

    init() {
        self.transcriptionModel = defaults.string(forKey: Keys.transcriptionModel)
            ?? Self.transcriptionModels[0]
        self.textModel = defaults.string(forKey: Keys.textModel)
            ?? Self.textModels[0]
        self.cleanupEnabled = defaults.object(forKey: Keys.cleanupEnabled) as? Bool ?? true
        self.dictationMode = DictationMode(rawValue: defaults.string(forKey: Keys.dictationMode) ?? "")
            ?? .toggle
        self.transcriptLogPath = defaults.string(forKey: Keys.transcriptLogPath)
            ?? Self.defaultLogPath()
        self.openWindowOnLaunch = defaults.object(forKey: Keys.openWindowOnLaunch) as? Bool ?? true
    }

    /// Reads the persisted dictation mode directly (used by the global hotkey
    /// handler, which has no view-injected settings instance).
    static func currentDictationMode() -> DictationMode {
        DictationMode(rawValue: UserDefaults.standard.string(forKey: Keys.dictationMode) ?? "")
            ?? .toggle
    }

    /// Reads the persisted transcription model (used off the view layer).
    static func currentTranscriptionModel() -> String {
        UserDefaults.standard.string(forKey: Keys.transcriptionModel) ?? transcriptionModels[0]
    }

    /// Reads the persisted text model (used off the view layer).
    static func currentTextModel() -> String {
        UserDefaults.standard.string(forKey: Keys.textModel) ?? textModels[0]
    }

    /// Reads whether dictation AI cleanup is enabled (used off the view layer).
    static func currentCleanupEnabled() -> Bool {
        UserDefaults.standard.object(forKey: Keys.cleanupEnabled) as? Bool ?? true
    }

    static func defaultLogPath() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return docs?.appendingPathComponent("zan-transcripts.md").path
            ?? "~/Documents/zan-transcripts.md"
    }

    private enum Keys {
        static let transcriptionModel = "transcriptionModel"
        static let textModel = "textModel"
        static let cleanupEnabled = "cleanupEnabled"
        static let dictationMode = "dictationMode"
        static let transcriptLogPath = "transcriptLogPath"
        static let openWindowOnLaunch = "openWindowOnLaunch"
    }
}
