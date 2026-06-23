import SwiftUI
import AppKit

/// A small bottom-center HUD shown while a text transform is running, since the
/// dropdown is usually closed when you trigger one from a hotkey.
@MainActor
final class TransformHUDController {
    private var panel: NSPanel?

    func show(_ controller: TransformController) {
        let panel = self.panel ?? makePanel(controller)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }

    private func makePanel(_ controller: TransformController) -> NSPanel {
        let hosting = NSHostingView(rootView: TransformHUDView(controller: controller))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 48))
    }
}

struct TransformHUDView: View {
    @ObservedObject var controller: TransformController

    var body: some View {
        HStack(spacing: 10) {
            if controller.isRunning {
                ProgressView().controlSize(.small)
            } else if controller.lastError != nil {
                Image(systemName: "exclamationmark.octagon.fill").foregroundStyle(.red)
            } else if (controller.statusMessage ?? "").hasSuffix("done") {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "info.circle.fill").foregroundStyle(.orange)
            }
            Text(controller.statusMessage ?? "Working…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .fixedSize()
    }
}
