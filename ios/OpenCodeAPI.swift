// OpenCodeAPI.swift — thin client over `opencode serve` (see docs/PROTOCOL.md)

import Foundation

struct OCMessage: Identifiable, Decodable {
    let id: String
    let role: String
    let text: String
}

struct OCSession: Identifiable, Decodable {
    let id: String
    let title: String?
}

final class OpenCodeAPI: ObservableObject {
    let baseURL: URL
    let username: String
    let password: String

    init(baseURL: URL, username: String, password: String) {
        self.baseURL = baseURL
        self.username = username
        self.password = password
    }

    private func request(_ path: String, method: String = "GET", body: Data? = nil) -> URLRequest {
        var r = URLRequest(url: baseURL.appendingPathComponent(path))
        r.httpMethod = method
        r.httpBody = body
        r.setValue("application/json", forHTTPHeaderField: "content-type")
        let creds = "\(username):\(password)".data(using: .utf8)!.base64EncodedString()
        r.setValue("Basic \(creds)", forHTTPHeaderField: "authorization")
        return r
    }

    func health() async throws -> Bool {
        let (data, _) = try await URLSession.shared.data(for: request("global/health"))
        return (try? JSONDecoder().decode([String: Bool].self, from: data))?["healthy"] == true
    }

    func listSessions() async throws -> [OCSession] {
        let (data, _) = try await URLSession.shared.data(for: request("session"))
        // Shape follows /doc OpenAPI; adjust after generating from live spec.
        struct Wrap: Decodable { let id: String; let title: String? }
        let raw = (try? JSONDecoder().decode([Wrap].self, from: data)) ?? []
        return raw.map { OCSession(id: $0.id, title: $0.title) }
    }

    func sendAsync(sessionID: String, text: String) async throws {
        let payload = ["parts": [["type": "text", "text": text]]]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await URLSession.shared.data(
            for: request("session/\(sessionID)/prompt_async", method: "POST", body: body)
        )
    }

    func abort(sessionID: String) async throws {
        _ = try await URLSession.shared.data(
            for: request("session/\(sessionID)/abort", method: "POST")
        )
    }

    func respondPermission(sessionID: String, permissionID: String, allow: Bool) async throws {
        let payload = ["response": allow ? "allow" : "reject"]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await URLSession.shared.data(
            for: request("session/\(sessionID)/permissions/\(permissionID)", method: "POST", body: body)
        )
    }

    /// SSE stream for live updates. Caller parses `data:` lines.
    func eventStream() -> URLRequest {
        request("global/event")
    }
}
