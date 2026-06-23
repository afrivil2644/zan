import Foundation

/// Transcribes audio via OpenAI's `/v1/audio/transcriptions` endpoint using a
/// multipart upload. Reads the API key from the Keychain at call time.
struct OpenAITranscriber: Transcriber {
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    func transcribe(fileURL: URL, model: String) async throws -> String {
        guard let apiKey = KeychainStore.openAIKey, !apiKey.isEmpty else {
            throw TranscriptionError(message: "No OpenAI API key. Add it in the dropdown.")
        }

        let audioData = try Data(contentsOf: fileURL)
        let boundary = "zan-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(
            boundary: boundary,
            fields: ["model": model, "response_format": "json"],
            fileField: "file",
            fileName: fileURL.lastPathComponent,
            fileData: audioData,
            mimeType: "audio/m4a"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptionError(message: "No response from OpenAI.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TranscriptionError(message: Self.apiErrorMessage(from: data, status: http.statusCode))
        }

        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw TranscriptionError(message: "Could not read transcript from OpenAI response.")
        }
        return decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private static func multipartBody(
        boundary: String,
        fields: [String: String],
        fileField: String,
        fileName: String,
        fileData: Data,
        mimeType: String
    ) -> Data {
        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }

        for (key, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            append("\(value)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n")
        append("--\(boundary)--\r\n")
        return body
    }

    private static func apiErrorMessage(from data: Data, status: Int) -> String {
        struct APIError: Decodable { struct E: Decodable { let message: String }; let error: E }
        if let decoded = try? JSONDecoder().decode(APIError.self, from: data) {
            return "OpenAI: \(decoded.error.message)"
        }
        return "OpenAI request failed (HTTP \(status))."
    }
}
