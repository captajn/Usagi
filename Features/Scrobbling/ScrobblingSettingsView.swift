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
                Text(String(localized: "Link tracking services to scrobble reading progress. OAuth uses ASWebAuthenticationSession in production; MVP uses a username link stub."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(accounts) { account in
                HStack {
                    Label(account.kind.displayName, systemImage: account.kind.systemImage)
                    Spacer()
                    if account.isLinked {
                        VStack(alignment: .trailing) {
                            Text(account.username ?? "linked")
                                .font(.caption)
                            Button(String(localized: "Unlink"), role: .destructive) {
                                Task {
                                    try? await dependencies.scrobblingService.unlink(kind: account.kind)
                                    await reload()
                                }
                            }
                            .font(.caption)
                        }
                    } else {
                        Button(String(localized: "Link")) {
                            linkingKind = account.kind
                            username = ""
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Scrobbling"))
        .task { await reload() }
        .alert(
            String(localized: "Link \(linkingKind?.displayName ?? "")"),
            isPresented: Binding(
                get: { linkingKind != nil },
                set: { if !$0 { linkingKind = nil } }
            )
        ) {
            TextField(String(localized: "Username"), text: $username)
            Button(String(localized: "Connect")) {
                guard let kind = linkingKind else { return }
                Task {
                    try? await dependencies.scrobblingService.link(kind: kind, username: username.isEmpty ? "user" : username)
                    linkingKind = nil
                    await reload()
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) { linkingKind = nil }
        }
    }

    private func reload() async {
        accounts = await dependencies.scrobblingService.accounts()
    }
}
