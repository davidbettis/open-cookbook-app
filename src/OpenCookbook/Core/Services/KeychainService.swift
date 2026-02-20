//
//  KeychainService.swift
//  OpenCookbook
//
//  Thin wrapper around the Security framework for storing API keys
//

import Security
import Foundation

struct KeychainService: Sendable {
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)
        case unexpectedData

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status): return "Keychain save failed: \(status)"
            case .readFailed(let status): return "Keychain read failed: \(status)"
            case .deleteFailed(let status): return "Keychain delete failed: \(status)"
            case .unexpectedData: return "Unexpected keychain data format"
            }
        }
    }

    private static let service = "com.opencookbook.api-keys"

    /// Save a string value to the Keychain
    static func save(key: String, value: String) throws(KeychainError) {
        guard let data = value.data(using: .utf8) else { throw .unexpectedData }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        // Try update first, fall back to add
        let updateAttributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw .saveFailed(addStatus) }
        } else if updateStatus != errSecSuccess {
            throw .saveFailed(updateStatus)
        }
    }

    /// Read a string value from the Keychain
    static func read(key: String) throws(KeychainError) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw .readFailed(status) }
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw .unexpectedData
        }
        return string
    }

    /// Delete a value from the Keychain
    static func delete(key: String) throws(KeychainError) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw .deleteFailed(status)
        }
    }
}
