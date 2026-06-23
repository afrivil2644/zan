import SwiftUI
import KeyboardShortcuts

/// Voice-to-Text settings: one dictation hotkey, the transcription engine, and
/// optional AI cleanup. This is dictation (a single trigger), distinct from the
/// Actions list below.
struct VoiceSectionView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Voice to Text", systemImage: "mic")
            Text("Dictate with one hotkey. Speech is transcribed and typed at your cursor.")
                .font(.caption2).foregroundStyle(.tertiary)

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

            LabeledRow("Engine") {
                Picker("", selection: $settings.transcriptionProvider) {
                    ForEach(AppSettings.TranscriptionProvider.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

            LabeledRow("Model") {
                ModelPickerField(selection: transcriptionModelBinding,
                                 presets: settings.transcriptionProvider.defaultModels)
            }

            Text(engineNote)
                .font(.caption2).foregroundStyle(.tertiary)

            Toggle("Clean up with AI", isOn: $settings.cleanupEnabled)
                .toggleStyle(.switch)

            if settings.cleanupEnabled {
                Text("Cleanup instructions")
                    .font(.caption).foregroundStyle(.secondary)
                PromptEditor(text: $settings.cleanupPrompt) { }
            }
        }
    }

    private var engineNote: String {
        switch settings.transcriptionProvider {
        case .openai:
            return "Uses your OpenAI key. Note: Claude/Anthropic has no speech-to-text API, so it can't transcribe voice."
        case .local:
            return "Runs on your Mac with Whisper. No key, fully private. First use downloads the model (a few hundred MB)."
        }
    }

    /// Binds to the active voice provider's model so each remembers its own.
    private var transcriptionModelBinding: Binding<String> {
        Binding(
            get: { settings.transcriptionProvider == .openai ? settings.transcriptionModel : settings.whisperModel },
            set: {
                if settings.transcriptionProvider == .openai { settings.transcriptionModel = $0 }
                else { settings.whisperModel = $0 }
            }
        )
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
