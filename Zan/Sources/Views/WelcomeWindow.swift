import SwiftUI
import AppKit

/// Shows a real window on launch so the app isn't invisible the first time.
/// While the window is open the app briefly becomes a regular (Dock-visible)
/// app; on close it returns to being a menu-bar-only agent.
@MainActor
final class WelcomeWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private var window: NSWindow?
    private var didShowThisLaunch = false

    func showOnce(content: AnyView) {
        guard !didShowThisLaunch else { return }
        didShowThisLaunch = true
        show(content: content)
    }

    func show(content: AnyView) {
        if let window {
            bringToFront(window)
            return
        }
        let hosting = NSHostingController(rootView: content)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Zan"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.isReleasedWhenClosed = false
        win.delegate = self
        win.setContentSize(hosting.view.fittingSize)
        win.center()
        window = win
        bringToFront(win)
    }

    private func bringToFront(_ win: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory) // back to menu-bar-only
    }
}

/// The launch window content: a one-line pointer to the menu bar, then the full
/// dropdown UI so the user can configure everything immediately.
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.up.forward.app")
                    .foregroundStyle(.tint)
                Text("Zan runs from your menu bar (the waveform icon, top-right). Set it up here, or open it from that icon anytime.")
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.12))

            MenuContentView()
        }
        .frame(width: 360)
    }
}
