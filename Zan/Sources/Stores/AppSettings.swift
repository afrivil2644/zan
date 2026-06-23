import Foundation
import Combine

/// Scalar app settings, persisted in UserDefaults. The API key is NOT here:
/// it goes to the Keychain (wired in Stage 3).
@MainActor
final class AppSettings: ObservableObject {
    /// Which engine transcribes dictation: OpenAI (cloud) or on-device Whisper.
    @Published var transcriptionProvider: TranscriptionProvider {
        didSet { defaults.set(transcriptionProvider.rawValue, forKey: Keys.transcriptionProvider) }
    }
    @Published var transcriptionModel: String {
        didSet { defaults.set(transcriptionModel, forKey: Keys.transcriptionModel) }
    }
    /// On-device Whisper model name (used when provider == local).
    @Published var whisperModel: String {
        didSet { defaults.set(whisperModel, forKey: Keys.whisperModel) }
    }
    /// Which provider powers text actions + dictation cleanup. (Transcription is
    /// always OpenAI; Anthropic has no audio API.)
    @Published var textProvider: TextProvider {
        didSet { defaults.set(textProvider.rawValue, forKey: Keys.textProvider) }
    }
    @Published var openAITextModel: String {
        didSet { defaults.set(openAITextModel, forKey: Keys.textModel) }
    }
    @Published var anthropicTextModel: String {
        didSet { defaults.set(anthropicTextModel, forKey: Keys.anthropicTextModel) }
    }
    @Published var cleanupEnabled: Bool {
        didSet { defaults.set(cleanupEnabled, forKey: Keys.cleanupEnabled) }
    }
    /// Editable prompt used to clean up dictation before insertion.
    @Published var cleanupPrompt: String {
        didSet { defaults.set(cleanupPrompt, forKey: Keys.cleanupPrompt) }
    }
    /// Dictation trigger behavior: toggle (press to start/stop) or hold-to-talk.
    @Published var dictationMode: DictationMode {
        didSet { defaults.set(dictationMode.rawValue, forKey: Keys.dictationMode) }
    }
    /// Show the app window automatically on launch (so it isn't invisible).
    @Published var openWindowOnLaunch: Bool {
        didSet { defaults.set(openWindowOnLaunch, forKey: Keys.openWindowOnLaunch) }
    }

    // Quick-pick presets. The fields are free-text too, so any model ID (incl.
    // ones newer than this list) can be typed in directly.
    static let transcriptionModels = ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
    static let whisperModels = ["tiny", "base", "small", "large-v3"]
    static let openAITextModels = ["gpt-4o-mini", "gpt-4.1-nano", "gpt-4.1-mini", "gpt-4.1", "gpt-4o"]
    static let anthropicTextModels = ["claude-haiku-4-5-20251001", "claude-sonnet-4-6", "claude-opus-4-8"]

    enum TranscriptionProvider: String, CaseIterable, Identifiable {
        case openai, local
        var id: String { rawValue }
        var label: String { self == .openai ? "OpenAI (cloud)" : "On-device" }
        var defaultModels: [String] {
            self == .openai ? AppSettings.transcriptionModels : AppSettings.whisperModels
        }
    }

    enum TextProvider: String, CaseIterable, Identifiable {
        case openai, anthropic
        var id: String { rawValue }
        var label: String { self == .openai ? "OpenAI" : "Anthropic" }
        var defaultModels: [String] {
            self == .openai ? AppSettings.openAITextModels : AppSettings.anthropicTextModels
        }
    }

    enum DictationMode: String, CaseIterable, Identifiable {
        case toggle, holdToTalk
        var id: String { rawValue }
        var label: String { self == .toggle ? "Toggle (press to start/stop)" : "Hold to talk" }
    }

    private let defaults = UserDefaults.standard

    init() {
        self.transcriptionProvider = TranscriptionProvider(
            rawValue: defaults.string(forKey: Keys.transcriptionProvider) ?? "") ?? .openai
        self.transcriptionModel = defaults.string(forKey: Keys.transcriptionModel)
            ?? Self.transcriptionModels[0]
        self.whisperModel = defaults.string(forKey: Keys.whisperModel) ?? "base"
        self.textProvider = TextProvider(rawValue: defaults.string(forKey: Keys.textProvider) ?? "")
            ?? .openai
        self.openAITextModel = defaults.string(forKey: Keys.textModel)
            ?? Self.openAITextModels[0]
        self.anthropicTextModel = defaults.string(forKey: Keys.anthropicTextModel)
            ?? Self.anthropicTextModels[0]
        self.cleanupEnabled = defaults.object(forKey: Keys.cleanupEnabled) as? Bool ?? true
        self.dictationMode = DictationMode(rawValue: defaults.string(forKey: Keys.dictationMode) ?? "")
            ?? .toggle
        self.openWindowOnLaunch = defaults.object(forKey: Keys.openWindowOnLaunch) as? Bool ?? true
        self.cleanupPrompt = defaults.string(forKey: Keys.cleanupPrompt) ?? Self.defaultCleanupPrompt
    }

    static let defaultCleanupPrompt = """
    Lightly clean up this dictated text. Fix grammar, punctuation, \
    capitalization, and remove filler words such as um, uh, and like. \
    Keep my wording and meaning. Do not rewrite or summarize. \
    Never use em dashes; use commas or restructure the sentence. \
    Return only the cleaned text.
    """

    /// Reads the persisted dictation mode directly (used by the global hotkey
    /// handler, which has no view-injected settings instance).
    static func currentDictationMode() -> DictationMode {
        DictationMode(rawValue: UserDefaults.standard.string(forKey: Keys.dictationMode) ?? "")
            ?? .toggle
    }

    /// Reads the persisted transcription provider (used off the view layer).
    static func currentTranscriptionProvider() -> TranscriptionProvider {
        TranscriptionProvider(rawValue: UserDefaults.standard.string(forKey: Keys.transcriptionProvider) ?? "")
            ?? .openai
    }

    /// Reads the transcription model for the active voice provider (off the view layer).
    static func currentTranscriptionModel() -> String {
        switch currentTranscriptionProvider() {
        case .openai:
            return UserDefaults.standard.string(forKey: Keys.transcriptionModel) ?? transcriptionModels[0]
        case .local:
            return UserDefaults.standard.string(forKey: Keys.whisperModel) ?? "base"
        }
    }

    /// Reads the persisted text provider (used off the view layer).
    static func currentTextProvider() -> TextProvider {
        TextProvider(rawValue: UserDefaults.standard.string(forKey: Keys.textProvider) ?? "") ?? .openai
    }

    /// Reads the persisted text model for the active provider (off the view layer).
    static func currentTextModel() -> String {
        switch currentTextProvider() {
        case .openai:
            return UserDefaults.standard.string(forKey: Keys.textModel) ?? openAITextModels[0]
        case .anthropic:
            return UserDefaults.standard.string(forKey: Keys.anthropicTextModel) ?? anthropicTextModels[0]
        }
    }

    /// Reads whether dictation AI cleanup is enabled (used off the view layer).
    static func currentCleanupEnabled() -> Bool {
        UserDefaults.standard.object(forKey: Keys.cleanupEnabled) as? Bool ?? true
    }

    /// Reads the persisted cleanup prompt (used off the view layer).
    static func currentCleanupPrompt() -> String {
        UserDefaults.standard.string(forKey: Keys.cleanupPrompt) ?? defaultCleanupPrompt
    }

    private enum Keys {
        static let transcriptionProvider = "transcriptionProvider"
        static let transcriptionModel = "transcriptionModel"
        static let whisperModel = "whisperModel"
        static let textModel = "textModel"
        static let textProvider = "textProvider"
        static let anthropicTextModel = "anthropicTextModel"
        static let cleanupEnabled = "cleanupEnabled"
        static let cleanupPrompt = "cleanupPrompt"
        static let dictationMode = "dictationMode"
        static let openWindowOnLaunch = "openWindowOnLaunch"
    }
}
