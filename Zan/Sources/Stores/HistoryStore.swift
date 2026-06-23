import Foundation

/// One completed action: a dictation or a text transform.
struct HistoryEntry: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case dictation, transform }

    var id = UUID()
    var date: Date
    var kind: Kind
    /// "Dictation" or the transform preset's name.
    var title: String
    /// Original selection (transforms only); empty for dictation.
    var input: String
    /// The resulting / inserted text.
    var output: String
}

/// Keeps a rolling list of recent actions, persisted to JSON so it survives
/// relaunches. Shown in the dropdown's "Recent activity" section.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []

    private let fileURL: URL
    private let maxEntries = 100

    init() {
        fileURL = PresetStore.appSupportDirectory().appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: fileURL),
           let stored = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            entries = stored
        }
    }

    func record(kind: HistoryEntry.Kind, title: String, input: String = "", output: String) {
        guard !output.isEmpty else { return }
        entries.insert(
            HistoryEntry(date: Date(), kind: kind, title: title, input: input, output: output),
            at: 0
        )
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
