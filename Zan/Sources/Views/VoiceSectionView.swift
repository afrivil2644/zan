import SwiftUI
import KeyboardShortcuts

/// Voice-to-Text settings: trigger hotkey, mode, transcription model,
/// AI cleanup toggle + editable cleanup prompt, and the transcript log path.
struct VoiceSectionView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Voice to Text", systemImage: "mic")

            // Trigger hotkey (real recorder; recording wiring lands in Stage 2).
            LabeledRow("Trigger key") {
                KeyboardShortcuts.Recorder(for: .dictationTrigger)
            }

            LabeledRow("Mode") {
                Picker("", selection: $settings.dictationMode) {
                    ForEach(AppSettings.DictationMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            LabeledRow("Model") {
                ModelPickerField(selection: $settings.transcriptionModel,
                                 presets: AppSettings.transcriptionModels)
            }

            Toggle("Clean up with AI", isOn: $settings.cleanupEnabled)
                .toggleStyle(.switch)

            if settings.cleanupEnabled {
                Text("Cleanup instructions")
                    .font(.caption).foregroundStyle(.secondary)
                PromptEditor(text: $settings.cleanupPrompt) { }
            }
        }
    }
}

// MARK: - Small reusable rows

/// A label on the left, a control on the right.
struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.callout).frame(width: 70, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
    }
}

/// An editable model picker: type any model ID, or pick a preset from the menu.
/// Future-proof against new OpenAI models not in the preset list.
struct ModelPickerField: View {
    @Binding var selection: String
    let presets: [String]
    var body: some View {
        HStack(spacing: 4) {
            TextField("model id", text: $selection)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())
            Menu {
                ForEach(presets, id: \.self) { model in
                    Button { selection = model } label: {
                        if model == selection { Label(model, systemImage: "checkmark") }
                        else { Text(model) }
                    }
                }
            } label: {
                Image(systemName: "chevron.down.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Choose a model")
        }
    }
}

/// A multi-line prompt editor that persists on every edit.
struct PromptEditor: View {
    @Binding var text: String
    var onChange: () -> Void
    var body: some View {
        TextEditor(text: $text)
            .font(.caption.monospaced())
            .frame(minHeight: 64, maxHeight: 110)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(.textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(.separatorColor)))
            .onChange(of: text) { _, _ in onChange() }
    }
}
