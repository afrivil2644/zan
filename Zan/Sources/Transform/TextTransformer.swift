import Foundation

/// Runs a prompt template over input text and returns transformed text. Backs
/// both the text transforms and (Stage 5) dictation cleanup. OpenAI today;
/// swappable to Anthropic later without touching callers.
protocol TextTransformer {
    func transform(prompt: String, text: String, model: String) async throws -> String
}

struct TransformError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
