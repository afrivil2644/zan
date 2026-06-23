import KeyboardShortcuts

/// Global hotkey identifiers. The dictation trigger is fixed; every action's
/// hotkey is derived per-action from `Action.shortcutKey` via
/// `KeyboardShortcuts.Name(action.shortcutKey)`.
extension KeyboardShortcuts.Name {
    static let dictationTrigger = Self("dictationTrigger")
}
