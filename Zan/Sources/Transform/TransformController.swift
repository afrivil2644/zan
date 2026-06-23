import Foundation
import AppKit
import Combine
import KeyboardShortcuts

/// Runs actions: each action's hotkey reads the selection, applies the action's
/// engine (AI prompt or a built-in text op), and delivers the result per the
/// action's output mode (replace selection / popup / copy).
@MainActor
final class TransformController: ObservableObject {
    @Published private(set) var isRunning = false
    @Published var statusMessage: String?
    @Published private(set) var lastError: String?

    private var actions: ActionStore?
    private var history: HistoryStore?
    private let hud = TransformHUDController()
    private let popup = InfoPopupController(title: "Result", icon: "sparkles")
    private var registeredKeys = Set<String>()
    private var cancellable: AnyCancellable?
    private var hideWorkItem: DispatchWorkItem?

    func bind(actions: ActionStore, history: HistoryStore) {
        self.actions = actions
        self.history = history
        registerNewKeys()
        cancellable = actions.$actions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.registerNewKeys() }
    }

    /// Register one handler per stable shortcut key; the handler looks the action
    /// up live so name/prompt/output edits always take effect.
    private func registerNewKeys() {
        guard let actions else { return }
        for action in actions.actions where !registeredKeys.contains(action.shortcutKey) {
            let key = action.shortcutKey
            registeredKeys.insert(key)
            KeyboardShortcuts.onKeyDown(for: KeyboardShortcuts.Name(key)) { [weak self] in
                MainActor.assumeIsolated { self?.run(shortcutKey: key) }
            }
        }
    }

    func run(shortcutKey: String) {
        guard let action = actions?.actions.first(where: { $0.shortcutKey == shortcutKey }),
              action.enabled else { return }
        run(action)
    }

    func run(_ action: Action) {
        guard !isRunning else { return }
        guard AccessibilityPermission.isTrusted else {
            AccessibilityPermission.request()
            flash("Enable Accessibility for actions")
            return
        }
        if action.engine == .ai && !KeychainStore.hasOpenAIKey {
            flash("Add your OpenAI API key first")
            return
        }
        SelectionReader.read { [weak self] selected in
            guard let self else { return }
            guard let selected else {
                self.flash("Select some text first")
                return
            }
            self.execute(action, on: selected)
        }
    }

    private func execute(_ action: Action, on text: String) {
        switch action.engine {
        case .prefix:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = trimmed.hasPrefix(action.prefix) ? trimmed : action.prefix + trimmed
            deliver(result, action: action, original: text)

        case .ai:
            isRunning = true
            lastError = nil
            statusMessage = "\(action.name)…"
            hideWorkItem?.cancel()
            if action.output == .popup {
                popup.model.title = action.name
                popup.showLoading()
            } else {
                hud.show(self)
            }
            let model = AppSettings.currentTextModel()
            let engine = TextEngineFactory.make()
            Task {
                do {
                    let result = try await engine.transform(
                        prompt: action.prompt, text: text, model: model)
                    self.deliver(result, action: action, original: text)
                } catch {
                    self.lastError = error.localizedDescription
                    if action.output == .popup {
                        self.popup.showError(error.localizedDescription)
                    } else {
                        self.statusMessage = "\(action.name) failed"
                        self.scheduleHide(after: 2.2)
                    }
                }
                self.isRunning = false
            }
        }
    }

    private func deliver(_ result: String, action: Action, original: String) {
        switch action.output {
        case .replaceSelection:
            hud.show(self)
            TextInjector.insert(result)
            statusMessage = "\(action.name) done"
            scheduleHide()
        case .copy:
            hud.show(self)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result, forType: .string)
            statusMessage = "\(action.name): copied"
            scheduleHide()
        case .popup:
            popup.model.title = action.name
            popup.showResult(result)
        }
        history?.record(kind: .transform, title: action.name, input: original, output: result)
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
