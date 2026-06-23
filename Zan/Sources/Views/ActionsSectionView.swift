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
    @State private var expanded: Bool
    @State private var showInfo = false

    init(action: Binding<Action>) {
        self._action = action
        // A nameless draft opens expanded so it can be named right away.
        let isDraft = action.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty
        self._expanded = State(initialValue: isDraft)
    }

    private var nameMissing: Bool {
        action.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

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

                Button { showInfo = true } label: {
                    Image(systemName: "info.circle").font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("What this action does")
                .popover(isPresented: $showInfo, arrowEdge: .bottom) {
                    ActionInfoPopover(action: action)
                }

                KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name(action.shortcutKey))
                    .controlSize(.small)
                    .frame(width: 116)

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
                if nameMissing {
                    Label("Add a name to save this action", systemImage: "exclamationmark.circle")
                        .font(.caption2).foregroundStyle(.orange)
                }

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
                .onChange(of: action.output) { _, newValue in
                    // Swap the starter template to match the new output, but only
                    // if the prompt is still an unedited template.
                    if action.engine == .ai && Action.starterPrompts.contains(action.prompt) {
                        action.prompt = Action.starterPrompt(for: newValue)
                    }
                    actions.save()
                }

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

/// Plain-language explanation of a single action: what it does, how to trigger
/// it, and what its output mode means.
struct ActionInfoPopover: View {
    let action: Action

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(action.name.isEmpty ? "New action" : action.name)
                .font(.headline)

            Text(action.detail.isEmpty ? "No description yet. Add one in the expanded view." : action.detail)
                .font(.callout)
                .foregroundStyle(action.detail.isEmpty ? .secondary : .primary)

            Divider()

            infoRow("How to use", "Select text in any app, then press this action's hotkey.")
            infoRow("Engine", engineText)
            infoRow("Output", outputText)
        }
        .padding(14)
        .frame(width: 270)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.caption)
        }
    }

    private var engineText: String {
        switch action.engine {
        case .ai:     return "Runs your prompt through the AI text model."
        case .prefix: return "Adds a fixed prefix to the selection (no AI)."
        }
    }

    private var outputText: String {
        switch action.output {
        case .replaceSelection: return "Replaces your selected text with the result."
        case .popup:            return "Shows the result in a popup; your text stays unchanged."
        case .copy:             return "Copies the result to your clipboard."
        }
    }
}
