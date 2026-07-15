import Foundation

enum DeepLink: Equatable {
    case manga(id: Int64)
    case search(query: String)
    case settings
    case downloads
    case tracker

    static func parse(_ url: URL) -> DeepLink? {
        // usagi://manga/1  |  https://usagi.app/manga/1
        let host = url.host?.lowercased() ?? ""
        let path = url.pathComponents.filter { $0 != "/" }

        if url.scheme == "usagi" {
            switch host {
            case "manga":
                if let idStr = path.first, let id = Int64(idStr) { return .manga(id: id) }
            case "search":
                let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "q" })?.value ?? path.first ?? ""
                return .search(query: q)
            case "settings": return .settings
            case "downloads": return .downloads
            case "tracker": return .tracker
            default: break
            }
        }

        if host.contains("usagi") {
            if path.first == "manga", let idStr = path.dropFirst().first, let id = Int64(idStr) {
                return .manga(id: id)
            }
            if path.first == "search" {
                let q = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "q" })?.value ?? ""
                return .search(query: q)
            }
        }
        return nil
    }
}

@MainActor
final class NavigationStore: ObservableObject {
    @Published var selectedTab: AppTab = .explore
    @Published var pendingMangaID: Int64?
    @Published var pendingSearch: String?
    @Published var showDownloads = false
    @Published var showBookmarks = false

    func handle(_ link: DeepLink) {
        switch link {
        case .manga(let id):
            selectedTab = .explore
            pendingMangaID = id
        case .search(let query):
            selectedTab = .search
            pendingSearch = query
        case .settings:
            selectedTab = .settings
        case .downloads:
            selectedTab = .settings
            showDownloads = true
        case .tracker:
            selectedTab = .tracker
        }
    }
}
