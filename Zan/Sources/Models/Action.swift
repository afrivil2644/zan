import Foundation

/// One unified action. Every selection-triggered feature is an Action: a name,
/// a description, a hotkey, an engine (AI prompt or a built-in text op), and an
/// output mode (replace the selection, show a popup, or copy to clipboard).
struct Action: Identifiable, Codable, Equatable {
    enum Engine: String, Codable {
        case ai      // runs `prompt` through the LLM
        case prefix  // prepends `prefix` to the selection (no AI)
    }

    enum Output: String, Codable, CaseIterable, Identifiable {
        case replaceSelection
        case popup
        case copy
        var id: String { rawValue }
        var label: String {
            switch self {
            case .replaceSelection: return "Replace selection"
            case .popup:            return "Show popup"
            case .copy:             return "Copy to clipboard"
            }
        }
    }

    var id = UUID()
    var name: String
    var detail: String
    var enabled: Bool = true
    var shortcutKey: String
    var engine: Engine = .ai
    /// Used when engine == .ai
    var prompt: String = ""
    /// Used when engine == .prefix
    var prefix: String = ""
    var output: Output = .replaceSelection
    var isBuiltIn: Bool = false

    static func makeShortcutKey() -> String { "action_\(UUID().uuidString)" }
}

extension Action {
    /// The actions Zan ships with. Built-ins keep stable `shortcutKey`s so saved
    /// hotkeys survive upgrades and the unification migration.
    static let defaults: [Action] = [
        Action(
            name: "Proofread",
            detail: "Fix grammar, punctuation, spelling. Keep wording.",
            shortcutKey: "transform_proofread",
            engine: .ai,
            prompt: """
            Proofread the selected text. Fix grammar, punctuation, capitalization, \
            and spelling. Keep my wording and meaning. Do not rewrite or summarize. \
            Never use em dashes; use commas or restructure the sentence. \
            Return only the corrected text.
            """,
            output: .replaceSelection,
            isBuiltIn: true
        ),
        Action(
            name: "Make professional",
            detail: "Rewrite in a clear, professional tone.",
            shortcutKey: "transform_professional",
            engine: .ai,
            prompt: """
            Rewrite the selected text in a clear, professional tone. \
            No corporate jargon, no filler. Keep the original meaning. \
            Never use em dashes; use commas or restructure the sentence. \
            Return only the rewritten text.
            """,
            output: .replaceSelection,
            isBuiltIn: true
        ),
        Action(
            name: "Strip em dashes",
            detail: "Replace em dashes with other punctuation, nothing else.",
            shortcutKey: "transform_stripemdash",
            engine: .ai,
            prompt: """
            Replace every em dash in the selected text with appropriate \
            punctuation (comma, colon, parentheses, or a sentence break). \
            Change nothing else. Return only the edited text.
            """,
            output: .replaceSelection,
            isBuiltIn: true
        ),
        Action(
            name: "Translate to English",
            detail: "Show an English translation in a popup (doesn't change text).",
            shortcutKey: "translatePopup",
            engine: .ai,
            prompt: """
            Detect the language of the following text and translate it into natural, \
            fluent English. Return only the translation, with no quotes, labels, or commentary.
            """,
            output: .popup,
            isBuiltIn: true
        ),
        Action(
            name: "Summarize",
            detail: "One sentence, or up to 3 bullets, in a popup.",
            shortcutKey: "summaryPopup",
            engine: .ai,
            prompt: """
            Summarize what the following text is about as briefly as possible. \
            Prefer a single short sentence. Only if one sentence cannot capture it, \
            use at most 3 short bullet points, each starting with "- ". \
            Return only the summary, no preamble.
            """,
            output: .popup,
            isBuiltIn: true
        ),
        Action(
            name: "Open in r.jina.ai",
            detail: "Prepend https://r.jina.ai/ to the selected URL.",
            shortcutKey: "jinaReader",
            engine: .prefix,
            prefix: "https://r.jina.ai/",
            output: .replaceSelection,
            isBuiltIn: true
        ),
    ]
}
