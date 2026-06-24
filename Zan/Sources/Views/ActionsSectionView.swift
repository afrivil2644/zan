import SwiftUI
import KeyboardShortcuts

/// The unified list of actions. Each has a name, description, hotkey, output
/// mode, and an editable prompt (AI) or prefix (built-in op).
struct ActionsSectionView: View {
    @EnvironmentObject var actions: ActionStore
    @EnvironmentObject var transforms: TransformController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                SectionHeader(title: "Text", systemImage: "wand.and.stars",
                              subtitle: "Select text anywhere, then press an action's hotkey")
                Spacer()
                Button { actions.addAction() } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("Add an action")
            }

            if transforms.needsAccessibility {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Allow Accessibility so actions can edit text.")
                        .font(.caption2)
                    Spacer()
                    Button("Open Settings") { transforms.openAccessibilitySettings() }
                        .font(.caption2).buttonStyle(.link)
                    Button("Recheck") { transforms.recheckAccessibility() }
                        .font(.caption2).buttonStyle(.link)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.1)))
            }

            // Only surface in-progress and error states here; successful "done"
            // feedback shows in the on-screen HUD, not as lingering text.
            if transforms.isRunning {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(transforms.statusMessage ?? "Working…")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } else if let error = transforms.lastError {
                Text(error).font(.caption2).foregroundStyle(.red)
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
    @State private var showDeleteConfirm = false

    init(action: Binding<Action>) {
        self._action = action
        // A nameless draft opens expanded so it can be named right away.
        let isDraft = action.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty
        self._expanded = State(initialValue: isDraft)
    }

    private var nameMissing: Bool {
        action.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasShortcut: Bool {
        KeyboardShortcuts.getShortcut(for: KeyboardShortcuts.Name(action.shortcutKey)) != nil
    }
    private var shortcutLabel: String {
        if let sc = KeyboardShortcuts.getShortcut(for: KeyboardShortcuts.Name(action.shortcutKey)) {
            return "\(sc)"
        }
        return "Set hotkey"
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

                // Compact hotkey badge; the full recorder lives in the expanded
                // view (the recorder control can't be made narrow inline).
                if !expanded {
                    Button { withAnimation(.easeInOut(duration: 0.12)) { expanded = true } } label: {
                        Text(shortcutLabel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(hasShortcut ? Color.primary : Color.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color(.windowBackgroundColor).opacity(0.9)))
                            .overlay(Capsule().strokeBorder(Color(.separatorColor)))
                    }
                    .buttonStyle(.plain)
                    .help("Set hotkey")
                }

            }

            if !action.detail.isEmpty && !expanded {
                Text(action.detail)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 20)
            }

            if expanded {
                Divider().padding(.vertical, 2)
                expandedDetail
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.windowBackgroundColor).opacity(0.5)))
    }

    // MARK: - Expanded editor

    private var expandedDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if nameMissing {
                Label("Add a name to save this action", systemImage: "exclamationmark.circle")
                    .font(.caption2).foregroundStyle(.orange)
            }

            // About block: a short, editable reminder of what this action does.
            VStack(alignment: .leading, spacing: 5) {
                Label("About this action", systemImage: "info.circle")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                TextField("Short description, e.g. \"Rewrite in a friendly tone\"",
                          text: $action.detail, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onChange(of: action.detail) { _, _ in actions.save() }
                Text(usageHint)
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.textBackgroundColor).opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(.separatorColor).opacity(0.6)))

            // Settings
            LabeledRow("Hotkey") {
                KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name(action.shortcutKey))
                    .controlSize(.small)
            }

            LabeledRow("Output") {
                Picker("", selection: $action.output) {
                    ForEach(Action.Output.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().fixedSize()
                .onChange(of: action.output) { _, newValue in
                    if action.engine == .ai && Action.starterPrompts.contains(action.prompt) {
                        action.prompt = Action.starterPrompt(for: newValue)
                    }
                    actions.save()
                }
            }

            if action.engine == .prefix {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prefix").font(.caption2).foregroundStyle(.secondary)
                    TextField("Prefix", text: $action.prefix)
                        .textFieldStyle(.roundedBorder).font(.caption.monospaced())
                        .onChange(of: action.prefix) { _, _ in actions.save() }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt").font(.caption2).foregroundStyle(.secondary)
                    PromptEditor(text: $action.prompt) { actions.save() }
                }
            }

            if !action.isBuiltIn {
                if showDeleteConfirm {
                    HStack(spacing: 8) {
                        Text("Delete this action?")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") { showDeleteConfirm = false }
                            .font(.caption2).buttonStyle(.plain)
                        Button { actions.delete(action) } label: {
                            Text("Delete").font(.caption2.weight(.semibold)).foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.08)))
                } else {
                    Button { showDeleteConfirm = true } label: {
                        Label("Delete action", systemImage: "trash")
                            .font(.caption).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.leading, 4)
    }

    private var usageHint: String {
        let outcome: String
        switch action.output {
        case .replaceSelection: outcome = "replaces your selection with the result"
        case .popup:            outcome = "shows the result in a popup (your text is unchanged)"
        case .copy:             outcome = "copies the result to the clipboard"
        }
        return "Select text, press the hotkey, and it \(outcome)."
    }

    private var outputIcon: String {
        switch action.output {
        case .replaceSelection: return "arrow.2.squarepath"
        case .popup:            return "rectangle.on.rectangle"
        case .copy:             return "doc.on.doc"
        }
    }
}
