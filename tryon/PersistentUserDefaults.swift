//
//  PersistentUserDefaults.swift
//  tryon
//
//  Created by Julian Beck on 21.03.25.
//



import Foundation
import Security

class PersistentUserDefaults {
    static let shared = PersistentUserDefaults()
    
    private init() {}
    
    func set(_ value: Int, forKey key: String) {
        let valueString = String(value)
        set(valueString, forKey: key)
    }
    
    func set(_ value: String, forKey key: String) {
        guard let valueData = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: valueData
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: valueData
            ]
            
            SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }
    
    func integer(forKey key: String) -> Int {
        guard let valueString = string(forKey: key) else { return 0 }
        return Int(valueString) ?? 0
    }
    
    func string(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        return nil
    }
    
    func removeValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
