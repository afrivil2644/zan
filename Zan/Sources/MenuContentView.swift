import SwiftUI
import KeyboardShortcuts

/// The menu-bar dropdown. Reference UX: a single panel with a Voice-to-Text
/// section and a Transforms section.
///
/// Scaffold status: all controls render and PERSIST (prompts -> JSON, settings
/// -> UserDefaults, hotkeys -> KeyboardShortcuts). The *actions* behind them
/// (recording, transcription, injection, transforms) get wired in Stages 2-7.
struct MenuContentView: View {
    @EnvironmentObject var presets: PresetStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            DictationStatusView()
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VoiceSectionView()
                    Divider()
                    TransformsSectionView()
                    Divider()
                    HistorySectionView()
                    Divider()
                    ApiKeySectionView()
                    Divider()
                    SystemSectionView()
                }
                .padding(14)
            }
            .frame(minHeight: 400, maxHeight: 520)

            Divider()
            footer
        }
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform").foregroundStyle(.tint)
            Text("Zan").font(.headline)
            Spacer()
            Text("v0.1").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Button("Reset prompts") { presets.resetToDefaults() }
                .font(.caption)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Section header helper

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

#Preview {
    MenuContentView()
        .environmentObject(PresetStore())
        .environmentObject(AppSettings())
        .environmentObject(DictationController())
        .environmentObject(TransformController())
        .environmentObject(HistoryStore())
        .environmentObject(PermissionsManager())
}
