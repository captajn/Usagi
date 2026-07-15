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

            Text("Mở khóa bằng \(dependencies.appLock.biometryLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if failed {
                Text("Xác thực thất bại. Thử lại.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    let ok = await dependencies.appLock.authenticate()
                    failed = !ok
                }
            } label: {
                Label("Mở khóa", systemImage: "faceid")
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
