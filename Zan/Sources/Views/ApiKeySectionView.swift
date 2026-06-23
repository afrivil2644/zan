import SwiftUI

/// AI provider settings: which provider powers text actions, the API keys (both
/// stored in the Keychain), and the text model for the active provider.
/// Transcription always uses OpenAI, so the OpenAI key is needed for dictation
/// regardless of the text provider.
struct ApiKeySectionView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "AI", systemImage: "key")

            VStack(alignment: .leading, spacing: 4) {
                Text("Text provider").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $settings.textProvider) {
                    ForEach(AppSettings.TextProvider.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Powers text actions and dictation cleanup. Transcription always uses OpenAI.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }

            KeyField(
                title: "OpenAI API key",
                placeholder: "sk-...",
                note: "Required for voice transcription" + (settings.textProvider == .openai ? " and text actions." : "."),
                hasKey: { KeychainStore.hasOpenAIKey },
                setKey: { KeychainStore.setOpenAIKey($0) }
            )

            KeyField(
                title: "Anthropic API key",
                placeholder: "sk-ant-...",
                note: "Used for text actions when the provider is Anthropic.",
                hasKey: { KeychainStore.hasAnthropicKey },
                setKey: { KeychainStore.setAnthropicKey($0) }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Text model (\(settings.textProvider.label))").font(.caption).foregroundStyle(.secondary)
                ModelPickerField(selection: textModelBinding,
                                 presets: settings.textProvider.defaultModels)
                Text("Used for actions and dictation cleanup.")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    /// Binds to the active provider's model so each provider remembers its own.
    private var textModelBinding: Binding<String> {
        Binding(
            get: { settings.textProvider == .openai ? settings.openAITextModel : settings.anthropicTextModel },
            set: {
                if settings.textProvider == .openai { settings.openAITextModel = $0 }
                else { settings.anthropicTextModel = $0 }
            }
        )
    }
}

/// A reusable Keychain-backed secret field.
private struct KeyField: View {
    let title: String
    let placeholder: String
    let note: String
    let hasKey: () -> Bool
    let setKey: (String) -> Void

    @State private var value = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.seal.fill")
                        .font(.caption2).foregroundStyle(.green)
                }
            }
            HStack(spacing: 6) {
                SecureField(placeholder, text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospaced())
                    .onSubmit(save)
                Button("Save", action: save)
                    .font(.caption)
                    .disabled(value.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text(note).font(.caption2).foregroundStyle(.tertiary)
        }
        .onAppear { saved = hasKey() }
    }

    private func save() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        setKey(trimmed)
        value = ""
        saved = true
    }
}
