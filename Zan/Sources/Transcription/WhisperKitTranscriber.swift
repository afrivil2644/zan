import Foundation
import WhisperKit

/// On-device transcription via WhisperKit. No API key, no cloud, fully private.
/// The first use of a given model downloads it (a few hundred MB) and caches it.
struct WhisperKitTranscriber: Transcriber {
    func transcribe(fileURL: URL, model: String) async throws -> String {
        try await WhisperKitEngine.shared.transcribe(path: fileURL.path, model: model)
    }
}

/// Caches the loaded WhisperKit pipeline so the model isn't reloaded every time.
actor WhisperKitEngine {
    static let shared = WhisperKitEngine()

    private var pipe: WhisperKit?
    private var loadedModel: String?

    func transcribe(path: String, model: String) async throws -> String {
        if pipe == nil || loadedModel != model {
            pipe = try await WhisperKit(WhisperKitConfig(model: model))
            loadedModel = model
        }
        guard let pipe else {
            throw TranscriptionError(message: "Could not load the on-device model.")
        }
        let results = try await pipe.transcribe(audioPath: path)
        let text = results.map(\.text).joined(separator: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
