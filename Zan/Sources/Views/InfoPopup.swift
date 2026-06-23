import SwiftUI
import AppKit

@MainActor
final class InfoPopupModel: ObservableObject {
    @Published var title: String
    @Published var icon: String
    @Published var isLoading = false
    @Published var text = ""
    @Published var error: String?

    init(title: String, icon: String) {
        self.title = title
        self.icon = icon
    }
}

/// A dismissible popup near the cursor that shows a read-only result (English
/// translation, summary, etc.) about the current selection, without changing
/// the selected text. Non-activating, so it doesn't steal focus.
@MainActor
final class InfoPopupController {
    let model: InfoPopupModel
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    init(title: String, icon: String) {
        model = InfoPopupModel(title: title, icon: icon)
    }

    func showLoading() {
        model.isLoading = true; model.error = nil; model.text = ""
        present(autoHide: false)
    }

    func showResult(_ text: String) {
        model.isLoading = false; model.error = nil; model.text = text
        present(autoHide: true)
    }

    func showError(_ message: String) {
        model.isLoading = false; model.error = message; model.text = ""
        present(autoHide: true)
    }

    func hide() {
        hideWork?.cancel()
        panel?.orderOut(nil)
    }

    private func present(autoHide: Bool) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        DispatchQueue.main.async {
            if let content = panel.contentView { panel.setContentSize(content.fittingSize) }
            self.positionNearMouse(panel)
            panel.orderFrontRegardless()
        }
        hideWork?.cancel()
        if autoHide {
            let work = DispatchWorkItem { [weak self] in self?.hide() }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
        }
    }

    private func makePanel() -> NSPanel {
        let view = InfoPopupView(
            model: model,
            onCopy: { [weak self] in
                guard let self else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(self.model.text, forType: .string)
            },
            onClose: { [weak self] in self?.hide() }
        )
        let hosting = NSHostingView(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = hosting
        return panel
    }

    private func positionNearMouse(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation // screen coords, origin bottom-left
        let size = panel.frame.size
        var x = mouse.x + 12
        var y = mouse.y - size.height - 12
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            x = min(max(vf.minX + 8, x), vf.maxX - size.width - 8)
            y = min(max(vf.minY + 8, y), vf.maxY - size.height - 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

struct InfoPopupView: View {
    @ObservedObject var model: InfoPopupModel
    var onCopy: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: model.icon).foregroundStyle(.tint)
                Text(model.title).font(.caption.weight(.semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if model.isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Working…").font(.caption).foregroundStyle(.secondary)
                }
            } else if let error = model.error {
                Text(error).font(.caption).foregroundStyle(.red)
            } else {
                ScrollView {
                    Text(model.text)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                HStack {
                    Spacer()
                    Button("Copy", action: onCopy).font(.caption2)
                }
            }
        }
        .padding(12)
        .frame(width: 320)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.12)))
    }
}
