import SwiftUI
import AppKit
import KeyboardShortcuts

/// A floating HUD shown at the bottom-center of the screen while recording.
/// It is a non-activating panel that never takes focus, so the app you are
/// dictating into keeps its cursor.
@MainActor
final class RecordingOverlayController {
    private var panel: NSPanel?

    func show(dictation: DictationController) {
        let panel = self.panel ?? makePanel(dictation: dictation)
        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel(dictation: DictationController) -> NSPanel {
        let hosting = NSHostingView(rootView:
            RecordingOverlayView().environmentObject(dictation)
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 230, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        // Clickable (for the Stop button) but still non-activating, so the app
        // you are dictating into keeps focus and its cursor.
        panel.ignoresMouseEvents = false
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
        let x = visible.midX - size.width / 2
        let y = visible.minY + 48
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// The pill HUD: pulsing dot + live waveform bars + a short hint.
struct RecordingOverlayView: View {
    @EnvironmentObject var dictation: DictationController
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .scaleEffect(pulse ? 1.0 : 0.55)
                .opacity(pulse ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

            WaveformBars(levels: dictation.levels)
                .frame(width: 110, height: 26)

            Button(action: { dictation.stop() }) {
                HStack(spacing: 5) {
                    Image(systemName: "stop.fill").font(.system(size: 9, weight: .bold))
                    Text("Stop").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.red))
            }
            .buttonStyle(.plain)
            .help(stopHint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .fixedSize()
        .onAppear { pulse = true }
    }

    private var stopHint: String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .dictationTrigger) {
            return "Stop recording (or press \(shortcut))"
        }
        return "Stop recording"
    }
}

/// Center-aligned bars whose heights track recent mic levels (newest at right).
struct WaveformBars: View {
    let levels: [CGFloat]

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color.primary.opacity(0.75))
                        .frame(height: barHeight(levels[i], max: geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: levels)
        }
    }

    private func barHeight(_ level: CGFloat, max: CGFloat) -> CGFloat {
        let minH: CGFloat = 3
        // Slight curve so quiet speech still shows visible motion.
        let shaped = pow(level, 0.7)
        return Swift.max(minH, shaped * max)
    }
}
