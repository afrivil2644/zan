import Foundation
import Combine

/// Owns the editable transform presets and the dictation cleanup preset.
/// Persists to JSON in Application Support so prompts survive relaunches and
/// can be edited without code changes.
@MainActor
final class PresetStore: ObservableObject {
    @Published var transforms: [Preset]
    @Published var cleanup: Preset

    private let fileURL: URL

    init() {
        let dir = PresetStore.appSupportDirectory()
        self.fileURL = dir.appendingPathComponent("presets.json")

        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            self.transforms = stored.transforms
            self.cleanup = stored.cleanup
        } else {
            self.transforms = Preset.defaultTransforms
            self.cleanup = Preset.defaultCleanup
        }
    }

    // MARK: - Mutations

    func addTransform() {
        let new = Preset(
            name: "New transform",
            prompt: "Describe what to do with the selected text. Return only the result.",
            shortcutKey: Preset.makeShortcutKey()
        )
        transforms.append(new)
        save()
    }

    func deleteTransform(_ preset: Preset) {
        transforms.removeAll { $0.id == preset.id }
        save()
    }

    func resetToDefaults() {
        transforms = Preset.defaultTransforms
        cleanup = Preset.defaultCleanup
        save()
    }

    /// Call after editing a preset's fields (name/prompt) to persist.
    func save() {
        let stored = Stored(transforms: transforms, cleanup: cleanup)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Persistence helpers

    private struct Stored: Codable {
        var transforms: [Preset]
        var cleanup: Preset
    }

    static func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Zan", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
