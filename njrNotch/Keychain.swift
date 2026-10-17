//
//  Keychain.swift
//  njrNotch
//

import Foundation
import Security

/// This app's generic-password items in the login keychain (the Spotify refresh token).
enum Keychain {
    private static let service = "com.njr.njrNotch"

    /// Checks without reading the secret, so it never shows a keychain prompt.
    static func contains(_ account: String) -> Bool {
        SecItemCopyMatching(query(account) as CFDictionary, nil) == errSecSuccess
    }

    static func read(_ account: String) -> String? {
        var query = query(account)
        query[kSecReturnData as String] = true
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func save(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = query(account)
            query[kSecValueData as String] = data
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) {
        SecItemDelete(query(account) as CFDictionary)
    }

    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}
