import Foundation

enum DownloadStatus: String, Codable, Sendable {
    case queued
    case downloading
    case paused
    case completed
    case failed

    var displayName: String {
        switch self {
        case .queued: return String(localized: "Queued")
        case .downloading: return String(localized: "Downloading")
        case .paused: return String(localized: "Paused")
        case .completed: return String(localized: "Completed")
        case .failed: return String(localized: "Failed")
        }
    }
}

struct DownloadItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var mangaID: Int64
    var mangaTitle: String
    var chapterID: Int64
    var chapterTitle: String
    var coverURL: String?
    var status: DownloadStatus
    var progress: Float
    var totalPages: Int
    var downloadedPages: Int
    var localDirectory: String?
    var errorMessage: String?
    var createdAt: Date
    var updatedAt: Date

    var percentText: String {
        "\(Int((progress * 100).rounded()))%"
    }
}

struct LocalChapterPackage: Identifiable, Hashable, Codable, Sendable {
    let id: String // "mangaID-chapterID"
    var mangaID: Int64
    var chapterID: Int64
    var mangaTitle: String
    var chapterTitle: String
    var pagePaths: [String]
    var importedAt: Date
    var source: LocalSourceKind

    enum LocalSourceKind: String, Codable, Sendable {
        case download
        case cbzImport
    }
}

struct ReadingTimeEstimate: Sendable {
    var minutes: Int
    var chapterCount: Int

    var displayText: String {
        if minutes < 60 {
            return String(localized: "~\(minutes) min")
        }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0
            ? String(localized: "~\(h) h")
            : String(localized: "~\(h) h \(m) min")
    }

    static func estimate(pages: Int, secondsPerPage: Double = 8) -> ReadingTimeEstimate {
        let minutes = max(1, Int((Double(pages) * secondsPerPage / 60.0).rounded()))
        return ReadingTimeEstimate(minutes: minutes, chapterCount: 0)
    }
}

struct TrackerEntry: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var manga: Manga
    var lastKnownChapters: Int
    var newChapters: Int
    var lastCheckedAt: Date
    var isNotifying: Bool

    var hasUpdates: Bool { newChapters > 0 }
}

enum ScrobblerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case anilist
    case myanimelist
    case kitsu
    case shikimori

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anilist: return "AniList"
        case .myanimelist: return "MyAnimeList"
        case .kitsu: return "Kitsu"
        case .shikimori: return "Shikimori"
        }
    }

    var systemImage: String {
        switch self {
        case .anilist: return "a.circle.fill"
        case .myanimelist: return "m.circle.fill"
        case .kitsu: return "k.circle.fill"
        case .shikimori: return "s.circle.fill"
        }
    }
}

struct ScrobblerAccount: Identifiable, Hashable, Codable, Sendable {
    var id: String { kind.rawValue }
    var kind: ScrobblerKind
    var username: String?
    var accessToken: String?
    var isLinked: Bool
    var lastSyncAt: Date?
}

struct SyncAccount: Hashable, Codable, Sendable {
    var email: String?
    var serverURL: String
    var isLoggedIn: Bool
    var lastSyncAt: Date?
    var deviceName: String

    static let `default` = SyncAccount(
        email: nil,
        serverURL: "https://sync.usagi.app",
        isLoggedIn: false,
        lastSyncAt: nil,
        deviceName: "iOS"
    )
}

struct BackupManifest: Codable, Sendable {
    var version: Int
    var createdAt: Date
    var appVersion: String
    var platform: String
    var mangaCount: Int
    var historyCount: Int
    var favouriteCount: Int
    var bookmarkCount: Int
}

struct AppBackupPayload: Codable, Sendable {
    var manifest: BackupManifest
    var favourites: [Manga]
    var categories: [FavouriteCategory]
    var history: [MangaHistoryEntry]
    var bookmarks: [Bookmark]
    var tracker: [TrackerEntry]
    var settings: BackupSettingsSnapshot
}

struct BackupSettingsSnapshot: Codable, Sendable {
    var readerMode: String
    var colorScheme: String
    var keepScreenOn: Bool
    var incognitoMode: Bool
    var dataSaver: Bool
    var showNSFW: Bool
}

struct ColorFilterConfig: Hashable, Codable, Sendable {
    var isEnabled: Bool = false
    var brightness: Double = 0
    var contrast: Double = 1
    var inversion: Bool = false
    var grayscale: Bool = false

    static let `default` = ColorFilterConfig()
}

enum TapZoneAction: String, Codable, CaseIterable, Sendable {
    case none
    case prevPage
    case nextPage
    case toggleUI

    var displayName: String {
        switch self {
        case .none: return String(localized: "None")
        case .prevPage: return String(localized: "Previous page")
        case .nextPage: return String(localized: "Next page")
        case .toggleUI: return String(localized: "Toggle UI")
        }
    }
}

struct TapGridConfig: Hashable, Codable, Sendable {
    var left: TapZoneAction = .prevPage
    var center: TapZoneAction = .toggleUI
    var right: TapZoneAction = .nextPage

    static let `default` = TapGridConfig()
}
