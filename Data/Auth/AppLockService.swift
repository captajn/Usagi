import Foundation
import LocalAuthentication

@MainActor
final class AppLockService: ObservableObject {
    @Published private(set) var isUnlocked = false
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Keys.enabled) }
    }

    private enum Keys {
        static let enabled = "appLock.enabled"
    }

    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        self.isUnlocked = !UserDefaults.standard.bool(forKey: Keys.enabled)
    }

    var biometryLabel: String {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return String(localized: "Passcode")
        }
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "Biometrics")
        }
    }

    func lock() {
        if isEnabled { isUnlocked = false }
    }

    func authenticate(reason: String = String(localized: "Unlock Usagi")) async -> Bool {
        if !isEnabled {
            isUnlocked = true
            return true
        }
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Cancel")
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication
        do {
            let ok = try await context.evaluatePolicy(policy, localizedReason: reason)
            isUnlocked = ok
            return ok
        } catch {
            AppLog.error("Auth failed", error: error)
            isUnlocked = false
            return false
        }
    }
}
