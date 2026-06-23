import KeyboardShortcuts

/// Global hotkey identifiers. The dictation trigger is fixed; transform hotkeys
/// are derived per-preset from `Preset.shortcutKey` so they can be added at
/// runtime. KeyboardShortcuts persists each binding under its name's raw value.
extension KeyboardShortcuts.Name {
    static let dictationTrigger = Self("dictationTrigger")
    /// Translate the selection to English and show it in a popup (read-only).
    static let translatePopup = Self("translatePopup")
    /// Summarize the selection and show it in a popup (read-only).
    static let summaryPopup = Self("summaryPopup")
    /// Prepend https://r.jina.ai/ to the selected URL (replaces selection).
    static let jinaReader = Self("jinaReader")

    /// A recorder name for a given preset's stable key.
    static func transform(_ key: String) -> Self { Self(key) }
}
