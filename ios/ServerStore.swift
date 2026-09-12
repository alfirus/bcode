// ServerStore.swift — server config in Keychain (never UserDefaults for password)

import Foundation
import Security

final class ServerStore: ObservableObject {
    @Published var baseURLString: String = ""
    @Published var username: String = "opencode"
    @Published var isConfigured: Bool = false

    private let urlKey = "bcode.server.url"
    private let userKey = "bcode.server.username"

    init() {
        if let url = load(key: urlKey), !url.isEmpty {
            baseURLString = url
            username = load(key: userKey) ?? "opencode"
            isConfigured = true
        }
    }

    func save(url: String, username: String, password: String) {
        store(key: urlKey, value: url)
        store(key: userKey, value: username)
        store(key: "bcode.server.password", value: password)
        baseURLString = url
        self.username = username
        isConfigured = true
    }

    func password() -> String { load(key: "bcode.server.password") ?? "" }

    func api() -> OpenCodeAPI? {
        guard let url = URL(string: baseURLString) else { return nil }
        return OpenCodeAPI(baseURL: url, username: username, password: password())
    }

    // MARK: - Keychain helpers
    private func store(key: String, value: String) {
        let data = value.data(using: .utf8)!
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ] as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        var out: AnyObject?
        SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ] as CFDictionary, &out)
        guard let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
