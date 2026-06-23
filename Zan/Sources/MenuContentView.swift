import SwiftUI
import KeyboardShortcuts

/// The menu-bar dropdown: a single panel with Voice to Text, Actions, Recent
/// activity, OpenAI, and System sections.
struct MenuContentView: View {
    @EnvironmentObject var actions: ActionStore
    @State private var showResetConfirm = false

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
                    ActionsSectionView()
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
        .frame(width: 432)
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
            Button("Reset actions") { showResetConfirm = true }
                .font(.caption)
                .confirmationDialog(
                    "Reset all actions to defaults?",
                    isPresented: $showResetConfirm, titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) { actions.resetToDefaults() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This removes your custom actions and restores the built-in ones. Your edits to built-in prompts are lost.")
                }

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
        .environmentObject(ActionStore())
        .environmentObject(AppSettings())
        .environmentObject(DictationController())
        .environmentObject(TransformController())
        .environmentObject(HistoryStore())
        .environmentObject(PermissionsManager())
}
