import Foundation
import Security

/// Stores API keys in the macOS Keychain. Keys are never written to disk in
/// plaintext, never logged, and never committed.
enum KeychainStore {
    static let service = "dev.local.zan"

    private static let openAIAccount = "openai-api-key"
    private static let anthropicAccount = "anthropic-api-key"

    // MARK: OpenAI

    static var openAIKey: String? { read(account: openAIAccount) }
    static var hasOpenAIKey: Bool { (openAIKey?.isEmpty == false) }
    static func setOpenAIKey(_ value: String) { setKey(value, account: openAIAccount) }

    // MARK: Anthropic

    static var anthropicKey: String? { read(account: anthropicAccount) }
    static var hasAnthropicKey: Bool { (anthropicKey?.isEmpty == false) }
    static func setAnthropicKey(_ value: String) { setKey(value, account: anthropicAccount) }

    // MARK: -

    private static func setKey(_ value: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            delete(account: account)
        } else {
            save(trimmed, account: account)
        }
    }

    // MARK: - Generic helpers

    private static func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    private static func read(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
