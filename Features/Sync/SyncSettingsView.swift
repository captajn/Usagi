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
            Section("Máy chủ") {
                TextField("URL máy chủ", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            }

            if account.isLoggedIn {
                Section("Tài khoản") {
                    LabeledContent("Email", value: account.email ?? "—")
                    if let last = account.lastSyncAt {
                        LabeledContent("Lần đồng bộ cuối", value: last.formatted())
                    }
                    Button {
                        Task { await sync() }
                    } label: {
                        if busy { ProgressView() } else { Text("Đồng bộ ngay") }
                    }
                    Button("Đăng xuất", role: .destructive) {
                        Task {
                            try? await dependencies.syncService.logout()
                            await reload()
                        }
                    }
                }
            } else {
                Section("Đăng nhập") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Mật khẩu", text: $password)
                    Button {
                        Task { await login() }
                    } label: {
                        if busy { ProgressView() } else { Text("Đăng nhập") }
                    }
                }
            }

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Đồng bộ")
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
            message = "Đăng nhập thành công (stub)."
        } catch {
            message = error.localizedDescription
        }
    }

    private func sync() async {
        busy = true
        defer { busy = false }
        do {
            account = try await dependencies.syncService.syncNow()
            message = "Đồng bộ hoàn tất."
        } catch {
            message = error.localizedDescription
        }
    }
}
