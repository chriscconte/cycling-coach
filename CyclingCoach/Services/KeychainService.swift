//
//  KeychainService.swift
//  CyclingCoach
//
//  Created on 2025-10-31.
//

import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private init() {}
    
    private let openAIKeyIdentifier = "com.cyclingcoach.openai.apikey"
    private let intervalsICUTokenIdentifier = "com.cyclingcoach.intervalsicu.token"
    
    func saveOpenAIKey(_ key: String) -> Bool {
        return save(key: key, identifier: openAIKeyIdentifier)
    }
    
    func getOpenAIKey() -> String? {
        return get(identifier: openAIKeyIdentifier)
    }
    
    func deleteOpenAIKey() -> Bool {
        return delete(identifier: openAIKeyIdentifier)
    }
    
    func saveIntervalsICUToken(_ token: String) -> Bool {
        return save(key: token, identifier: intervalsICUTokenIdentifier)
    }
    
    func getIntervalsICUToken() -> String? {
        return get(identifier: intervalsICUTokenIdentifier)
    }
    
    func deleteIntervalsICUToken() -> Bool {
        return delete(identifier: intervalsICUTokenIdentifier)
    }
    
    private func save(key: String, identifier: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        // Delete any existing key first
        delete(identifier: identifier)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func get(identifier: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    private func delete(identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

