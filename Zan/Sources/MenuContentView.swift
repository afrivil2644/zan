import SwiftUI
import KeyboardShortcuts

/// The menu-bar dropdown: a single panel with Voice to Text, Actions, Recent
/// activity, OpenAI, and System sections.
struct MenuContentView: View {
    @EnvironmentObject var actions: ActionStore
    @State private var showResetConfirm = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.1"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionCard(accent: .purple) { ActionsSectionView() }
                    SectionCard(accent: .blue) { VoiceSectionView() }
                    SectionCard { HistorySectionView() }
                    SectionCard { ApiKeySectionView() }
                    SectionCard { SystemSectionView() }
                }
                .padding(14)
            }
            .frame(minHeight: 400, maxHeight: 540)

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
            Text("v\(appVersion)").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            if showResetConfirm {
                Text("Reset all?").font(.caption2).foregroundStyle(.secondary)
                Button("Cancel") { showResetConfirm = false }.font(.caption2)
                Button { actions.resetToDefaults(); showResetConfirm = false } label: {
                    Text("Reset").font(.caption2.weight(.semibold)).foregroundStyle(.red)
                }
            } else {
                Button("Reset actions") { showResetConfirm = true }
                    .font(.caption)
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

// MARK: - Section building blocks

/// A visually distinct card that groups one section. An optional accent tints a
/// thin top edge so Voice and Actions read as clearly different areas.
struct SectionCard<Content: View>: View {
    var accent: Color?
    @ViewBuilder var content: Content

    init(accent: Color? = nil, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(accent?.opacity(0.06) ?? Color(.windowBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent?.opacity(0.5) ?? Color(.separatorColor).opacity(0.6),
                              lineWidth: accent == nil ? 1 : 1.5)
        )
    }
}

/// Prominent section header: tinted icon + bold title, with optional subtitle.
struct SectionHeader: View {
    let title: String
    let systemImage: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
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
