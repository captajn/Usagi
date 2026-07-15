import SwiftUI
import AuthenticationServices

struct ScrobblingSettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var accounts: [ScrobblerAccount] = []
    @State private var linkingKind: ScrobblerKind?
    @State private var username = ""

    var body: some View {
        List {
            Section {
                Text("Liên kết dịch vụ theo dõi để ghi lại tiến độ đọc. OAuth sử dụng ASWebAuthenticationSession; MVP dùng liên kết tên người dùng.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(accounts) { account in
                HStack {
                    Label(account.kind.displayName, systemImage: account.kind.systemImage)
                    Spacer()
                    if account.isLinked {
                        VStack(alignment: .trailing) {
                            Text(account.username ?? "đã liên kết")
                                .font(.caption)
                            Button("Hủy liên kết", role: .destructive) {
                                Task {
                                    try? await dependencies.scrobblingService.unlink(kind: account.kind)
                                    await reload()
                                }
                            }
                            .font(.caption)
                        }
                    } else {
                        Button("Liên kết") {
                            linkingKind = account.kind
                            username = ""
                        }
                    }
                }
            }
        }
        .navigationTitle("Scrobbling")
        .task { await reload() }
        .alert(
            "Liên kết \(linkingKind?.displayName ?? "")",
            isPresented: Binding(
                get: { linkingKind != nil },
                set: { if !$0 { linkingKind = nil } }
            )
        ) {
            TextField("Tên người dùng", text: $username)
            Button("Kết nối") {
                guard let kind = linkingKind else { return }
                Task {
                    try? await dependencies.scrobblingService.link(kind: kind, username: username.isEmpty ? "user" : username)
                    linkingKind = nil
                    await reload()
                }
            }
            Button("Huỷ", role: .cancel) { linkingKind = nil }
        }
    }

    private func reload() async {
        accounts = await dependencies.scrobblingService.accounts()
    }
}
