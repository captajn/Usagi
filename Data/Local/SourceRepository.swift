import Foundation

/// Manages manga source definitions — built-in + custom user-added sources.
/// Persistent storage via UserDefaults + JSON file.
@MainActor
final class SourceRepository: ObservableObject {
    @Published private(set) var sources: [ManagedSource] = []

    private let userDefaults = UserDefaults.standard
    private let customKey = "custom_manga_sources"
    private let enabledKey = "enabled_sources"

    struct ManagedSource: Identifiable, Codable, Hashable {
        let id: String
        let name: String
        let locale: String
        let apiBaseURL: String
        let isBuiltIn: Bool
        var isEnabled: Bool

        var displayLocale: String { locale.uppercased() }
    }

    init() {
        load()
    }

    // MARK: - Public

    func allSources() -> [ManagedSource] { sources }

    func enabledSources() -> [ManagedSource] { sources.filter(\.isEnabled) }

    func toggleSource(_ id: String, enabled: Bool) {
        if let i = sources.firstIndex(where: { $0.id == id }) {
            sources[i].isEnabled = enabled
            save()
        }
    }

    func addCustomSource(name: String, locale: String, apiBaseURL: String) -> Bool {
        let id = "custom.\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        guard !sources.contains(where: { $0.id == id }) else { return false }
        let source = ManagedSource(
            id: id,
            name: name,
            locale: locale,
            apiBaseURL: apiBaseURL,
            isBuiltIn: false,
            isEnabled: true
        )
        sources.append(source)
        save()
        return true
    }

    func removeCustomSource(_ id: String) {
        sources.removeAll { $0.id == id && !$0.isBuiltIn }
        save()
    }

    // MARK: - Persistence

    private func load() {
        // Built-in sources
        let builtIn: [ManagedSource] = [
            ManagedSource(id: "mangadex", name: "MangaDex", locale: "EN", apiBaseURL: "https://api.mangadex.org", isBuiltIn: true, isEnabled: true),
        ]

        // Custom sources from UserDefaults
        let custom: [ManagedSource] = (userDefaults.data(forKey: customKey)
            .flatMap { try? JSONDecoder().decode([ManagedSource].self, from: $0) }) ?? []

        // Enabled state
        let enabledSet = Set(userDefaults.stringArray(forKey: enabledKey) ?? builtIn.map(\.id))

        sources = builtIn.map { s in
            var m = s
            m.isEnabled = enabledSet.contains(s.id)
            return m
        } + custom.map { s in
            var m = s
            m.isEnabled = enabledSet.contains(s.id)
            return m
        }
    }

    private func save() {
        let custom = sources.filter { !$0.isBuiltIn }
        if let data = try? JSONEncoder().encode(custom) {
            userDefaults.set(data, forKey: customKey)
        }
        let enabled = sources.filter(\.isEnabled).map(\.id)
        userDefaults.set(enabled, forKey: enabledKey)
    }
}
