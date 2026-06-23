import Foundation

/// A transform = (prompt template) + (input text) -> (output text).
///
/// Both the dictation cleanup and every text action are the same shape; this
/// one model backs all of them. `shortcutKey` is the stable string used to
/// build a `KeyboardShortcuts.Name`, so presets can be added/removed at runtime
/// and still own a hotkey.
struct Preset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var prompt: String
    /// Stable key for this preset's global hotkey (maps to KeyboardShortcuts.Name).
    var shortcutKey: String
    /// Built-in presets ship with the app; the user may edit their prompt but
    /// we keep the flag so the UI can mark them and avoid accidental deletion.
    var isBuiltIn: Bool = false

    static func makeShortcutKey() -> String { "transform_\(UUID().uuidString)" }
}

extension Preset {
    /// The four transforms the app ships with. Prompts are fully editable.
    static let defaultTransforms: [Preset] = [
        Preset(
            name: "Proofread",
            prompt: """
            Proofread the selected text. Fix grammar, punctuation, capitalization, \
            and spelling. Keep my wording and meaning. Do not rewrite or summarize. \
            Never use em dashes; use commas or restructure the sentence. \
            Return only the corrected text.
            """,
            shortcutKey: "transform_proofread",
            isBuiltIn: true
        ),
        Preset(
            name: "Make professional",
            prompt: """
            Rewrite the selected text in a clear, professional tone. \
            No corporate jargon, no filler. Keep the original meaning. \
            Never use em dashes; use commas or restructure the sentence. \
            Return only the rewritten text.
            """,
            shortcutKey: "transform_professional",
            isBuiltIn: true
        ),
        Preset(
            name: "Strip em dashes",
            prompt: """
            Replace every em dash in the selected text with appropriate \
            punctuation (comma, colon, parentheses, or a sentence break). \
            Change nothing else. Return only the edited text.
            """,
            shortcutKey: "transform_stripemdash",
            isBuiltIn: true
        ),
    ]

    /// The dictation cleanup preset (light touch, toggleable, default ON).
    static let defaultCleanup = Preset(
        name: "Dictation cleanup",
        prompt: """
        Lightly clean up this dictated text. Fix grammar, punctuation, \
        capitalization, and remove filler words such as um, uh, and like. \
        Keep my wording and meaning. Do not rewrite or summarize. \
        Never use em dashes; use commas or restructure the sentence. \
        Return only the cleaned text.
        """,
        shortcutKey: "dictation_cleanup",
        isBuiltIn: true
    )
}
