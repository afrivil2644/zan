import Foundation
import Combine
import KeyboardShortcuts

/// Routes each transform preset's global hotkey to: read selection → run the
/// preset's prompt → replace the selection with the result.
@MainActor
final class TransformController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var statusMessage: String?
    @Published private(set) var lastError: String?

    private var presets: PresetStore?
    private var history: HistoryStore?
    private let transformer: TextTransformer = OpenAITransformer()
    private let hud = TransformHUDController()
    private let translatePopup = InfoPopupController(title: "English translation", icon: "character.bubble")
    private let summaryPopup = InfoPopupController(title: "Summary", icon: "list.bullet.rectangle")
    private var registeredKeys = Set<String>()
    private var popupsRegistered = false
    private var cancellable: AnyCancellable?
    private var hideWorkItem: DispatchWorkItem?

    private static let translateToEnglishPrompt = """
    Detect the language of the following text and translate it into natural, \
    fluent English. Return only the translation, with no quotes, labels, or commentary.
    """

    private static let summarizePrompt = """
    Summarize what the following text is about as briefly as possible. \
    Prefer a single short sentence. Only if one sentence cannot capture it, \
    use at most 3 short bullet points, each starting with "- ". \
    Return only the summary, no preamble.
    """

    /// Wire up to the preset store and register hotkeys. Safe to call more than
    /// once; handlers are registered once per stable shortcut key.
    func bind(presets: PresetStore, history: HistoryStore) {
        self.presets = presets
        self.history = history
        registerNewKeys()
        cancellable = presets.$transforms
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerNewKeys() }

        if !popupsRegistered {
            popupsRegistered = true
            KeyboardShortcuts.onKeyDown(for: .translatePopup) { [weak self] in
                MainActor.assumeIsolated { self?.runTranslatePopup() }
            }
            KeyboardShortcuts.onKeyDown(for: .summaryPopup) { [weak self] in
                MainActor.assumeIsolated { self?.runSummaryPopup() }
            }
            KeyboardShortcuts.onKeyDown(for: .jinaReader) { [weak self] in
                MainActor.assumeIsolated { self?.runJinaReader() }
            }
        }
    }

    private func registerNewKeys() {
        guard let presets else { return }
        for preset in presets.transforms where !registeredKeys.contains(preset.shortcutKey) {
            let key = preset.shortcutKey
            registeredKeys.insert(key)
            KeyboardShortcuts.onKeyDown(for: .transform(key)) { [weak self] in
                MainActor.assumeIsolated { self?.run(shortcutKey: key) }
            }
        }
    }

    /// Look up the preset live (so prompt/name edits are always current) and run.
    func run(shortcutKey: String) {
        guard let preset = presets?.transforms.first(where: { $0.shortcutKey == shortcutKey }) else {
            return
        }
        run(preset)
    }

    func run(_ preset: Preset) {
        guard !isRunning else { return }
        guard KeychainStore.hasOpenAIKey else {
            flash("Add your OpenAI API key first")
            return
        }
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.request()
            flash("Enable Accessibility for transforms")
            return
        }

        SelectionReader.read { [weak self] selected in
            guard let self else { return }
            guard let selected else {
                self.flash("Select some text first")
                return
            }
            self.perform(preset: preset, on: selected)
        }
    }

    /// Translate the current selection to English and show it in a popup,
    /// leaving the selected text unchanged.
    func runTranslatePopup() {
        runPopup(prompt: Self.translateToEnglishPrompt,
                 historyTitle: "Translate to English", popup: translatePopup)
    }

    /// Summarize the current selection and show it in a popup, read-only.
    func runSummaryPopup() {
        runPopup(prompt: Self.summarizePrompt, historyTitle: "Summary", popup: summaryPopup)
    }

    /// Replace the selected URL with its Jina Reader form (prepend r.jina.ai).
    /// Pure string op, no API call.
    func runJinaReader() {
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.request()
            flash("Enable Accessibility for this")
            return
        }
        SelectionReader.read { [weak self] selected in
            guard let self else { return }
            guard let selected else {
                self.flash("Select a URL first")
                return
            }
            let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = "https://r.jina.ai/"
            let result = trimmed.hasPrefix(prefix) ? trimmed : prefix + trimmed
            TextInjector.insert(result)
            self.history?.record(kind: .transform, title: "Jina Reader URL",
                                 input: selected, output: result)
            self.flash("r.jina.ai added")
        }
    }

    /// Shared read-only flow: read selection → transform → show in `popup`.
    private func runPopup(prompt: String, historyTitle: String, popup: InfoPopupController) {
        guard KeychainStore.hasOpenAIKey else {
            popup.showError("Add your OpenAI API key first.")
            return
        }
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.request()
            popup.showError("Enable Accessibility to read the selection.")
            return
        }
        SelectionReader.read { [weak self] selected in
            guard let self else { return }
            guard let selected else {
                popup.showError("Select some text first.")
                return
            }
            popup.showLoading()
            let model = AppSettings.currentTextModel()
            Task {
                do {
                    let result = try await self.transformer.transform(
                        prompt: prompt, text: selected, model: model)
                    popup.showResult(result)
                    self.history?.record(kind: .transform, title: historyTitle,
                                         input: selected, output: result)
                } catch {
                    popup.showError(error.localizedDescription)
                }
            }
        }
    }

    private func perform(preset: Preset, on text: String) {
        isRunning = true
        lastError = nil
        statusMessage = "\(preset.name)…"
        hideWorkItem?.cancel()
        hud.show(self)

        let model = AppSettings.currentTextModel()
        Task {
            do {
                let result = try await transformer.transform(prompt: preset.prompt, text: text, model: model)
                self.history?.record(kind: .transform, title: preset.name, input: text, output: result)
                TextInjector.insert(result)
                self.statusMessage = "\(preset.name) done"
                self.scheduleHide()
            } catch {
                self.lastError = error.localizedDescription
                self.statusMessage = "Transform failed"
                self.scheduleHide(after: 2.2)
            }
            self.isRunning = false
        }
    }

    // MARK: - HUD helpers

    private func flash(_ message: String) {
        statusMessage = message
        lastError = nil
        hideWorkItem?.cancel()
        hud.show(self)
        scheduleHide(after: 1.8)
    }

    private func scheduleHide(after seconds: TimeInterval = 0.8) {
        let work = DispatchWorkItem { [weak self] in self?.hud.hide() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
}
