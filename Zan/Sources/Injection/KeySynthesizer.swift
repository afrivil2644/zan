import Foundation
import CoreGraphics

/// Synthesizes Command-modified keystrokes (Cmd+C, Cmd+V) into the frontmost
/// app. Requires Accessibility permission.
@MainActor
enum KeySynthesizer {
    static let cKey: CGKeyCode = 8 // 'c'
    static let vKey: CGKeyCode = 9 // 'v'

    static func postCommand(_ keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Runs `action` once the user has released the hotkey modifier keys, so a
    /// still-held ⌘/⌥/⌃/⇧ can't contaminate the synthesized Cmd+C / Cmd+V.
    /// Falls back to running anyway after `timeout`.
    static func afterModifiersReleased(timeout: TimeInterval = 1.0,
                                       _ action: @escaping @MainActor () -> Void) {
        let busy: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let start = Date()
        func poll() {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            if flags.intersection(busy).isEmpty || Date().timeIntervalSince(start) > timeout {
                action()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                    MainActor.assumeIsolated { poll() }
                }
            }
        }
        poll()
    }
}
