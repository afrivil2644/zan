import Foundation

/// Runs a prompt template over input text and returns transformed text. Backs
/// both the text actions and dictation cleanup, behind OpenAI or Anthropic.
protocol TextTransformer {
    func transform(prompt: String, text: String, model: String) async throws -> String
}

struct TransformError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Returns the transformer for the currently selected text provider.
enum TextEngineFactory {
    @MainActor
    static func make() -> TextTransformer {
        switch AppSettings.currentTextProvider() {
        case .openai:    return OpenAITransformer()
        case .anthropic: return AnthropicTransformer()
        }
    }
}
