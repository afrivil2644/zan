import SwiftUI
import KeyboardShortcuts

/// The list of text transforms. Each has its own hotkey and editable prompt.
/// Built-in presets can be edited but not deleted; custom ones can be added.
struct TransformsSectionView: View {
    @EnvironmentObject var presets: PresetStore
    @EnvironmentObject var transforms: TransformController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Transforms", systemImage: "wand.and.stars")
                Spacer()
                Button {
                    presets.addTransform()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("Add a transform")
            }

            Text("Select text in any app, then press a transform's hotkey to replace it.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            // Read-only popups: show a result without changing the selection.
            PopupActionRow(
                icon: "character.bubble",
                title: "Translate to English (popup)",
                subtitle: "Shows a translation without changing your text",
                shortcut: .translatePopup
            )
            PopupActionRow(
                icon: "list.bullet.rectangle",
                title: "Summarize (popup)",
                subtitle: "One sentence, or up to 3 bullets, doesn't change your text",
                shortcut: .summaryPopup
            )
            PopupActionRow(
                icon: "link",
                title: "Open in r.jina.ai",
                subtitle: "Replaces the selected URL with https://r.jina.ai/<url>",
                shortcut: .jinaReader
            )

            if let status = transforms.statusMessage {
                HStack(spacing: 6) {
                    if transforms.isRunning { ProgressView().controlSize(.small) }
                    Text(status).font(.caption2)
                        .foregroundStyle(transforms.lastError == nil ? Color.secondary : Color.red)
                }
            }

            ForEach($presets.transforms) { $preset in
                TransformRow(preset: $preset)
            }
        }
    }
}

/// A pinned read-only action (translate / summarize) with its own hotkey.
struct PopupActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let shortcut: KeyboardShortcuts.Name

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.caption2).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                Text(subtitle).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            KeyboardShortcuts.Recorder(for: shortcut)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor).opacity(0.5)))
    }
}

struct TransformRow: View {
    @Binding var preset: Preset
    @EnvironmentObject var presets: PresetStore
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    expanded.toggle()
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                TextField("Name", text: $preset.name)
                    .textFieldStyle(.plain)
                    .font(.callout.weight(.medium))
                    .onChange(of: preset.name) { _, _ in presets.save() }

                Spacer()

                KeyboardShortcuts.Recorder(for: .transform(preset.shortcutKey))

                if !preset.isBuiltIn {
                    Button {
                        presets.deleteTransform(preset)
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if expanded {
                PromptEditor(text: $preset.prompt) { presets.save() }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor).opacity(0.5)))
    }
}
