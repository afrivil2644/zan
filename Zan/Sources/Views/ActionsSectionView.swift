import SwiftUI
import KeyboardShortcuts

/// The unified list of actions. Each has a name, description, hotkey, output
/// mode, and an editable prompt (AI) or prefix (built-in op).
struct ActionsSectionView: View {
    @EnvironmentObject var actions: ActionStore
    @EnvironmentObject var transforms: TransformController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Actions", systemImage: "wand.and.stars")
                Spacer()
                Button { actions.addAction() } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("Add an action")
            }

            Text("Select text in any app, then press an action's hotkey.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let status = transforms.statusMessage {
                HStack(spacing: 6) {
                    if transforms.isRunning { ProgressView().controlSize(.small) }
                    Text(status).font(.caption2)
                        .foregroundStyle(transforms.lastError == nil ? Color.secondary : Color.red)
                }
            }

            ForEach($actions.actions) { $action in
                ActionRow(action: $action)
            }
        }
    }
}

struct ActionRow: View {
    @Binding var action: Action
    @EnvironmentObject var actions: ActionStore
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button { expanded.toggle() } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: outputIcon).font(.caption2).foregroundStyle(.tint)
                    .help(action.output.label)

                TextField("Name", text: $action.name)
                    .textFieldStyle(.plain)
                    .font(.callout.weight(.medium))
                    .onChange(of: action.name) { _, _ in actions.save() }

                Spacer()

                KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name(action.shortcutKey))

                if !action.isBuiltIn {
                    Button { actions.delete(action) } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !action.detail.isEmpty && !expanded {
                Text(action.detail)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 20)
            }

            if expanded {
                Toggle("Enabled", isOn: $action.enabled)
                    .toggleStyle(.switch).font(.caption)
                    .onChange(of: action.enabled) { _, _ in actions.save() }

                TextField("Description", text: $action.detail)
                    .textFieldStyle(.roundedBorder).font(.caption2)
                    .onChange(of: action.detail) { _, _ in actions.save() }

                Picker("Output", selection: $action.output) {
                    ForEach(Action.Output.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu).font(.caption)
                .onChange(of: action.output) { _, _ in actions.save() }

                if action.engine == .prefix {
                    TextField("Prefix", text: $action.prefix)
                        .textFieldStyle(.roundedBorder).font(.caption.monospaced())
                        .onChange(of: action.prefix) { _, _ in actions.save() }
                } else {
                    Text("Prompt").font(.caption2).foregroundStyle(.secondary)
                    PromptEditor(text: $action.prompt) { actions.save() }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor).opacity(0.5)))
        .opacity(action.enabled ? 1 : 0.5)
    }

    private var outputIcon: String {
        switch action.output {
        case .replaceSelection: return "arrow.2.squarepath"
        case .popup:            return "rectangle.on.rectangle"
        case .copy:             return "doc.on.doc"
        }
    }
}
