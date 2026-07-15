import SwiftUI

struct SyncSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var account = SyncAccount.default
    @State private var email = ""
    @State private var password = ""
    @State private var serverURL = SyncAccount.default.serverURL
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        Form {
            Section(String(localized: "Server")) {
                TextField(String(localized: "Server URL"), text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            if account.isLoggedIn {
                Section(String(localized: "Account")) {
                    LabeledContent(String(localized: "Email"), value: account.email ?? "—")
                    if let last = account.lastSyncAt {
                        LabeledContent(String(localized: "Last sync"), value: last.formatted())
                    }
                    Button {
                        Task { await sync() }
                    } label: {
                        if busy { ProgressView() } else { Text(String(localized: "Sync now")) }
                    }
                    Button(String(localized: "Log out"), role: .destructive) {
                        Task {
                            try? await dependencies.syncService.logout()
                            await reload()
                        }
                    }
                }
            } else {
                Section(String(localized: "Sign in")) {
                    TextField(String(localized: "Email"), text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField(String(localized: "Password"), text: $password)
                    Button {
                        Task { await login() }
                    } label: {
                        if busy { ProgressView() } else { Text(String(localized: "Log in")) }
                    }
                }
            }

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle(String(localized: "Sync"))
        .task { await reload() }
    }

    private func reload() async {
        account = await dependencies.syncService.account()
        serverURL = account.serverURL
        email = account.email ?? ""
    }

    private func login() async {
        busy = true
        defer { busy = false }
        do {
            account = try await dependencies.syncService.login(email: email, password: password, serverURL: serverURL)
            message = String(localized: "Logged in (stub).")
        } catch {
            message = error.localizedDescription
        }
    }

    private func sync() async {
        busy = true
        defer { busy = false }
        do {
            account = try await dependencies.syncService.syncNow()
            message = String(localized: "Sync completed.")
        } catch {
            message = error.localizedDescription
        }
    }
}
