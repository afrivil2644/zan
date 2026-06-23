import AppKit

/// Reads the current selection in the frontmost app by snapshotting the
/// pasteboard, synthesizing Cmd+C, reading the result after a short delay, then
/// restoring the original pasteboard. Requires Accessibility permission.
@MainActor
enum SelectionReader {
    /// `completion` gets the selected text, or nil if nothing was selected.
    static func read(copyDelay: TimeInterval = 0.15,
                     completion: @escaping @MainActor (String?) -> Void) {
        let pasteboard = NSPasteboard.general

        // Wait for the trigger keys to be released, otherwise the synthesized
        // Cmd+C is contaminated by held modifiers and copies nothing.
        KeySynthesizer.afterModifiersReleased {
            let saved = PasteboardHelper.snapshot(pasteboard)
            pasteboard.clearContents() // so "nothing selected" reads empty, not stale
            KeySynthesizer.postCommand(KeySynthesizer.cKey)

            DispatchQueue.main.asyncAfter(deadline: .now() + copyDelay) {
                MainActor.assumeIsolated {
                    let copied = pasteboard.string(forType: .string)
                    PasteboardHelper.restore(saved, to: pasteboard)
                    let trimmed = copied?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    completion(trimmed.isEmpty ? nil : copied)
                }
            }
        }
    }
}
