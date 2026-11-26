import Foundation
import Security

enum TokenStore {
    private static let service = "com.falcaosl.lulu"
    private static let account = "huggingface"

    static func load() -> String {
        KeychainSecret.load(service: service, account: account)
    }

    static func save(_ token: String) {
        KeychainSecret.save(token, service: service, account: account)
    }

    /// Token da UI, ou o que já estiver no ambiente. Não ecoa o valor do ambiente.
    static func effective() -> String? {
        let stored = load().trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }
        let env = ProcessInfo.processInfo.environment
        let fallback = env["HF_TOKEN"] ?? env["HUGGING_FACE_HUB_TOKEN"] ?? ""
        return fallback.isEmpty ? nil : fallback
    }
}

enum AccessKeyStore {
    private static let service = "com.falcaosl.lulu"
    private static let account = "access-key"

    static func load() -> String {
        KeychainSecret.load(service: service, account: account)
    }

    @discardableResult
    static func ensure() -> String {
        let existing = load().trimmingCharacters(in: .whitespacesAndNewlines)
        if !existing.isEmpty { return existing }
        return regenerate()
    }

    @discardableResult
    static func regenerate() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let key: String
        if status == errSecSuccess {
            key = "lulu_" + bytes.map { String(format: "%02x", $0) }.joined()
        } else {
            key = "lulu_" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        KeychainSecret.save(key, service: service, account: account)
        return key
    }
}

enum KeychainSecret {
    static func load(service: String, account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }

    static func save(_ secret: String, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        let trimmed = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var insert = query
        insert[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(insert as CFDictionary, nil)
    }
}
