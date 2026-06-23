import Foundation

/// Turns an audio file into text. Cloud-first today (OpenAI); a local WhisperKit
/// engine can be added later without touching callers.
protocol Transcriber {
    func transcribe(fileURL: URL, model: String) async throws -> String
}

/// A human-readable API/transcription error surfaced to the UI.
struct TranscriptionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
