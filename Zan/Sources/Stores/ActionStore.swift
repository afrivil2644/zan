import Foundation
import Combine

/// Owns the unified list of actions, persisted to JSON. Migrates from the old
/// presets.json (transforms + cleanup) so existing custom actions, prompts, and
/// hotkeys carry over. Built-in defaults missing from disk are added on load, so
/// app updates can introduce new built-ins without wiping user edits.
@MainActor
final class ActionStore: ObservableObject {
    @Published var actions: [Action]

    private let fileURL: URL

    init() {
        let dir = AppPaths.appSupport()
        fileURL = dir.appendingPathComponent("actions.json")

        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([Action].self, from: data) {
            actions = stored
            ensureBuiltins()
        } else if let migrated = Self.migrateFromPresets(in: dir) {
            actions = migrated
            ensureBuiltins()
            save()
        } else {
            actions = Action.defaults
            save()
        }
    }

    // MARK: - Mutations

    /// Adds a blank draft at the top. Not persisted until it has a name (see
    /// `save()`), so abandoning an unnamed draft leaves nothing on disk.
    func addAction() {
        actions.insert(Action(
            name: "",
            detail: "",
            shortcutKey: Action.makeShortcutKey(),
            engine: .ai,
            prompt: Action.starterPrompt(for: .replaceSelection),
            output: .replaceSelection
        ), at: 0)
        // Intentionally no save(): a nameless draft should not be stored.
    }

    func add(_ action: Action) {
        actions.append(action)
        save()
    }

    func delete(_ action: Action) {
        actions.removeAll { $0.id == action.id }
        save()
    }

    func resetToDefaults() {
        actions = Action.defaults
        save()
    }

    /// Persists only named actions; unnamed drafts are never written to disk.
    func save() {
        let named = actions.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard let data = try? JSONEncoder().encode(named) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Built-ins / migration

    private func ensureBuiltins() {
        let existing = Set(actions.map(\.shortcutKey))
        for builtin in Action.defaults where !existing.contains(builtin.shortcutKey) {
            actions.append(builtin)
        }
    }

    /// Old format: presets.json = { transforms: [Preset], cleanup: Preset }.
    private static func migrateFromPresets(in dir: URL) -> [Action]? {
        let presetsURL = dir.appendingPathComponent("presets.json")
        guard let data = try? Data(contentsOf: presetsURL),
              let old = try? JSONDecoder().decode(OldPresetStore.self, from: data) else {
            return nil
        }

        // Carry the user's cleanup prompt over to AppSettings if not already set.
        if UserDefaults.standard.string(forKey: "cleanupPrompt") == nil {
            UserDefaults.standard.set(old.cleanup.prompt, forKey: "cleanupPrompt")
        }

        return old.transforms.map { p in
            Action(name: p.name, detail: "", shortcutKey: p.shortcutKey,
                   engine: .ai, prompt: p.prompt, output: .replaceSelection,
                   isBuiltIn: p.isBuiltIn)
        }
    }

    private struct OldPreset: Decodable {
        var name: String
        var prompt: String
        var shortcutKey: String
        var isBuiltIn: Bool
    }
    private struct OldPresetStore: Decodable {
        var transforms: [OldPreset]
        var cleanup: OldPreset
    }
}
