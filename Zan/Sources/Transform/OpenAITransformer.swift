import Foundation

/// Calls OpenAI's chat completions endpoint with the preset prompt as the system
/// message and the user's text as the user message.
struct OpenAITransformer: TextTransformer {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func transform(prompt: String, text: String, model: String) async throws -> String {
        guard let apiKey = KeychainStore.openAIKey, !apiKey.isEmpty else {
            throw TransformError(message: "No OpenAI API key. Add it in the dropdown.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TransformError(message: "No response from OpenAI.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TransformError(message: Self.apiErrorMessage(from: data, status: http.statusCode))
        }

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = decoded.choices.first?.message.content else {
            throw TransformError(message: "Could not read result from OpenAI response.")
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func apiErrorMessage(from data: Data, status: Int) -> String {
        struct APIError: Decodable { struct E: Decodable { let message: String }; let error: E }
        if let decoded = try? JSONDecoder().decode(APIError.self, from: data) {
            return "OpenAI: \(decoded.error.message)"
        }
        return "OpenAI request failed (HTTP \(status))."
    }
}
