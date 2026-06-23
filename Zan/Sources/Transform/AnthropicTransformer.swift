import Foundation

/// Calls Anthropic's Messages API. The preset prompt is the system prompt and
/// the user's text is the user message.
struct AnthropicTransformer: TextTransformer {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func transform(prompt: String, text: String, model: String) async throws -> String {
        guard let apiKey = KeychainStore.anthropicKey, !apiKey.isEmpty else {
            throw TransformError(message: "No Anthropic API key. Add it in the dropdown.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": prompt,
            "messages": [
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TransformError(message: "No response from Anthropic.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TransformError(message: Self.apiErrorMessage(from: data, status: http.statusCode))
        }

        struct MessageResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        guard let decoded = try? JSONDecoder().decode(MessageResponse.self, from: data) else {
            throw TransformError(message: "Could not read result from Anthropic response.")
        }
        let result = decoded.content.compactMap { $0.text }.joined()
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func apiErrorMessage(from data: Data, status: Int) -> String {
        struct APIError: Decodable { struct E: Decodable { let message: String }; let error: E }
        if let decoded = try? JSONDecoder().decode(APIError.self, from: data) {
            return "Anthropic: \(decoded.error.message)"
        }
        return "Anthropic request failed (HTTP \(status))."
    }
}
