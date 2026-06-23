import Foundation

/// Turns an audio file into text. OpenAI (cloud) or WhisperKit (on-device).
/// Anthropic has no speech-to-text API, so Claude can't be a voice provider.
protocol Transcriber {
    func transcribe(fileURL: URL, model: String) async throws -> String
}

/// A human-readable API/transcription error surfaced to the UI.
struct TranscriptionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Returns the transcriber for the currently selected voice provider.
enum TranscriberFactory {
    @MainActor
    static func make() -> Transcriber {
        switch AppSettings.currentTranscriptionProvider() {
        case .openai: return OpenAITranscriber()
        case .local:  return WhisperKitTranscriber()
        }
    }
}
