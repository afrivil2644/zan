import SwiftUI

/// OpenAI settings: the API key (one key powers both transcription and text
/// transforms) and the text model used for transforms + dictation cleanup.
/// Scaffold: the key field renders but is held in memory only; persisting to
/// the macOS Keychain is wired in Stage 3.
struct ApiKeySectionView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var apiKey = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "OpenAI", systemImage: "key")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("API key").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if saved {
                        Label("Saved to Keychain", systemImage: "checkmark.seal.fill")
                            .font(.caption2).foregroundStyle(.green)
                    }
                }
                HStack(spacing: 6) {
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .onSubmit(save)
                    Button("Save", action: save)
                        .font(.caption)
                        .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Powers transcription and text transforms. Stored in the macOS Keychain.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Text model").font(.caption).foregroundStyle(.secondary)
                ModelPickerField(selection: $settings.textModel,
                                 presets: AppSettings.textModels)
                Text("Used for transforms and dictation cleanup.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear {
            // Show a masked placeholder if a key already exists; don't echo it.
            saved = KeychainStore.hasOpenAIKey
            if saved { apiKey = "" }
        }
    }

    private func save() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.setOpenAIKey(trimmed)
        apiKey = ""
        saved = true
    }
}
