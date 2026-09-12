// BcodeApp.swift — bcode iOS v0.1 skeleton (SwiftUI, native)
// Transport: OpenCode `serve` HTTP API + SSE. No WebSockets.
// Secrets: server URL + password in Keychain (see ServerStore).

import SwiftUI

@main
struct BcodeApp: App {
    @StateObject private var store = ServerStore()

    var body: some Scene {
        WindowGroup {
            if store.isConfigured {
                SessionListView()
                    .environmentObject(store)
            } else {
                ServerSetupView()
                    .environmentObject(store)
            }
        }
    }
}
