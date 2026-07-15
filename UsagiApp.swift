import SwiftUI

@main
struct UsagiApp: App {
    @StateObject private var dependencies = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if dependencies.isReady {
                    if dependencies.appLock.isEnabled && !dependencies.appLock.isUnlocked {
                        AppLockGateView()
                    } else {
                        RootTabView()
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Starting Usagi…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .environmentObject(dependencies)
            .preferredColorScheme(dependencies.settings.colorSchemePreference.colorScheme)
            .task { await dependencies.bootstrap() }
            .onOpenURL { url in
                if let link = DeepLink.parse(url) {
                    dependencies.navigation.handle(link)
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    dependencies.appLock.lock()
                }
            }
        }
    }
}
