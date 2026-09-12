// Views.swift — ServerSetup + SessionList + Chat (v0.1 skeleton)

import SwiftUI

struct ServerSetupView: View {
    @EnvironmentObject var store: ServerStore
    @State private var url = "http://100.121.188.113:4096"
    @State private var username = "opencode"
    @State private var password = ""
    @State private var error = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Server (over Tailscale)") {
                    TextField("http://<tailscale-ip>:4096", text: $url)
                        .textInputAutocapitalization(.never)
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                    SecureField("password (OPENCODE_SERVER_PASSWORD)", text: $password)
                }
                if !error.isEmpty { Text(error).foregroundColor(.red) }
                Button("Connect") {
                    Task {
                        do {
                            guard let u = URL(string: url) else { throw URLError(.badURL) }
                            let api = OpenCodeAPI(baseURL: u, username: username, password: password)
                            if try await api.health() {
                                store.save(url: url, username: username, password: password)
                            } else {
                                error = "Server replied but not healthy."
                            }
                        } catch {
                            error = "Cannot reach server: \(error.localizedDescription)"
                        }
                    }
                }
            }
            .navigationTitle("bcode setup")
        }
    }
}

struct SessionListView: View {
    @EnvironmentObject var store: ServerStore
    @State private var sessions: [OCSession] = []

    var body: some View {
        NavigationView {
            List(sessions) { s in
                NavigationLink(s.title ?? s.id) {
                    ChatView(session: s).environmentObject(store)
                }
            }
            .navigationTitle("Sessions")
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    func reload() async {
        guard let api = store.api() else { return }
        sessions = (try? await api.listSessions()) ?? []
    }
}

struct ChatView: View {
    @EnvironmentObject var store: ServerStore
    let session: OCSession
    @State private var draft = ""
    @State private var log: [String] = []

    var body: some View {
        VStack {
            List(log, id: \.self) { Text($0) }
            HStack {
                TextField("Ask opencode…", text: $draft)
                Button("Send") {
                    Task {
                        guard let api = store.api() else { return }
                        let text = draft; draft = ""
                        log.append("you: \(text)")
                        try? await api.sendAsync(sessionID: session.id, text: text)
                        log.append("…streaming reply via SSE (wire up eventStream next)")
                    }
                }
            }.padding()
        }
        .navigationTitle(session.title ?? "chat")
    }
}
