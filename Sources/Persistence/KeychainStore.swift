import Foundation
import Security

/// Minimal Keychain wrapper for the user's own portal credentials.
///
/// Only the signed-in user's own username/password are stored here (for silent
/// re-authentication after the lazily-detected session expiry) — never guest
/// data, never tokens scraped from the portal.
enum KeychainStore {

    private static let service = "com.caserocu.ios.portal"

    enum Key: String {
        case username
        case password
    }

    static func set(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        var query = baseQuery(for: key)
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: Key) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func remove(_ key: Key) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    static func clearAll() {
        remove(.username)
        remove(.password)
    }

    private static func baseQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
    }
}
