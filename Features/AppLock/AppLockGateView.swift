import SwiftUI

struct AppLockGateView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var failed = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(UsagiTheme.accent)
                .accessibilityHidden(true)

            Text("Usagi")
                .font(.largeTitle.weight(.bold))

            Text(String(localized: "Unlock with \(dependencies.appLock.biometryLabel)"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if failed {
                Text(String(localized: "Authentication failed. Try again."))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    let ok = await dependencies.appLock.authenticate()
                    failed = !ok
                }
            } label: {
                Label(
                    String(localized: "Unlock"),
                    systemImage: "faceid"
                )
                .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .task {
            _ = await dependencies.appLock.authenticate()
        }
        .accessibilityElement(children: .contain)
    }
}
