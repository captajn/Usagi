import Foundation
import SwiftUI
import Combine

@MainActor
final class UserDefaultsSettingsStore: SettingsStore, ObservableObject {
    private let defaults: UserDefaults
    private enum Key {
        static let readerMode = "settings.readerMode"
        static let colorScheme = "settings.colorScheme"
        static let keepScreenOn = "settings.keepScreenOn"
        static let incognito = "settings.incognito"
        static let dataSaver = "settings.dataSaver"
        static let showNSFW = "settings.showNSFW"
        static let autoScroll = "settings.autoScroll"
        static let autoScrollSeconds = "settings.autoScrollSeconds"
        static let colorFilter = "settings.colorFilter"
        static let tapGrid = "settings.tapGrid"
        static let brightness = "settings.readerBrightness"
    }

    @Published var readerMode: ReaderMode {
        didSet { defaults.set(readerMode.rawValue, forKey: Key.readerMode) }
    }

    @Published var colorSchemePreference: ColorSchemePreference {
        didSet { defaults.set(colorSchemePreference.rawValue, forKey: Key.colorScheme) }
    }

    @Published var keepScreenOn: Bool {
        didSet { defaults.set(keepScreenOn, forKey: Key.keepScreenOn) }
    }

    @Published var incognitoMode: Bool {
        didSet { defaults.set(incognitoMode, forKey: Key.incognito) }
    }

    @Published var dataSaver: Bool {
        didSet { defaults.set(dataSaver, forKey: Key.dataSaver) }
    }

    @Published var showNSFW: Bool {
        didSet { defaults.set(showNSFW, forKey: Key.showNSFW) }
    }

    @Published var autoScrollEnabled: Bool {
        didSet { defaults.set(autoScrollEnabled, forKey: Key.autoScroll) }
    }

    @Published var autoScrollSeconds: Double {
        didSet { defaults.set(autoScrollSeconds, forKey: Key.autoScrollSeconds) }
    }

    @Published var readerBrightness: Double {
        didSet { defaults.set(readerBrightness, forKey: Key.brightness) }
    }

    @Published var colorFilter: ColorFilterConfig {
        didSet {
            if let data = try? JSONEncoder().encode(colorFilter) {
                defaults.set(data, forKey: Key.colorFilter)
            }
        }
    }

    @Published var tapGrid: TapGridConfig {
        didSet {
            if let data = try? JSONEncoder().encode(tapGrid) {
                defaults.set(data, forKey: Key.tapGrid)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.readerMode = ReaderMode(rawValue: defaults.string(forKey: Key.readerMode) ?? "") ?? .pager
        self.colorSchemePreference = ColorSchemePreference(rawValue: defaults.string(forKey: Key.colorScheme) ?? "") ?? .system
        self.keepScreenOn = defaults.object(forKey: Key.keepScreenOn) as? Bool ?? true
        self.incognitoMode = defaults.bool(forKey: Key.incognito)
        self.dataSaver = defaults.bool(forKey: Key.dataSaver)
        self.showNSFW = defaults.object(forKey: Key.showNSFW) as? Bool ?? false
        self.autoScrollEnabled = defaults.bool(forKey: Key.autoScroll)
        self.autoScrollSeconds = defaults.object(forKey: Key.autoScrollSeconds) as? Double ?? 5
        self.readerBrightness = defaults.object(forKey: Key.brightness) as? Double ?? 1
        if let data = defaults.data(forKey: Key.colorFilter),
           let decoded = try? JSONDecoder().decode(ColorFilterConfig.self, from: data) {
            self.colorFilter = decoded
        } else {
            self.colorFilter = .default
        }
        if let data = defaults.data(forKey: Key.tapGrid),
           let decoded = try? JSONDecoder().decode(TapGridConfig.self, from: data) {
            self.tapGrid = decoded
        } else {
            self.tapGrid = .default
        }
    }

    func snapshot() -> BackupSettingsSnapshot {
        BackupSettingsSnapshot(
            readerMode: readerMode.rawValue,
            colorScheme: colorSchemePreference.rawValue,
            keepScreenOn: keepScreenOn,
            incognitoMode: incognitoMode,
            dataSaver: dataSaver,
            showNSFW: showNSFW
        )
    }

    func apply(snapshot: BackupSettingsSnapshot) {
        readerMode = ReaderMode(rawValue: snapshot.readerMode) ?? readerMode
        colorSchemePreference = ColorSchemePreference(rawValue: snapshot.colorScheme) ?? colorSchemePreference
        keepScreenOn = snapshot.keepScreenOn
        incognitoMode = snapshot.incognitoMode
        dataSaver = snapshot.dataSaver
        showNSFW = snapshot.showNSFW
    }
}
