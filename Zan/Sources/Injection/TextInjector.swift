import AppKit

/// Inserts text at the cursor in the frontmost app: snapshot pasteboard → put
/// our text on it → synthesize Cmd+V → restore the original pasteboard.
/// Requires Accessibility permission.
@MainActor
enum TextInjector {
    static func insert(_ text: String, restoreDelay: TimeInterval = 0.3) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general

        // Wait for any held trigger modifiers to clear, so the synthesized Cmd+V
        // is a real paste (not Cmd+Opt+V etc.) and replaces the selection.
        KeySynthesizer.afterModifiersReleased {
            let saved = PasteboardHelper.snapshot(pasteboard)
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            KeySynthesizer.postCommand(KeySynthesizer.vKey)

            DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
                MainActor.assumeIsolated { PasteboardHelper.restore(saved, to: pasteboard) }
            }
        }
    }
}
