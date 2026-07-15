import Foundation

/// Settings contract. Concrete store: `UserDefaultsSettingsStore`.
@MainActor
protocol SettingsStore: AnyObject {
    var readerMode: ReaderMode { get set }
    var colorSchemePreference: ColorSchemePreference { get set }
    var keepScreenOn: Bool { get set }
    var incognitoMode: Bool { get set }
    var dataSaver: Bool { get set }
    var showNSFW: Bool { get set }
}
