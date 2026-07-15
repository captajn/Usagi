import Foundation

/// File-backed persistence (Application Support). Maps Room tables conceptually without GRDB dependency.
actor AppDatabase {
    static let shared = AppDatabase()

    private let root: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var mangaCache: [Int64: Manga] = [:]
    private var history: [Int64: MangaHistoryEntry] = [:]
    private var categories: [FavouriteCategory] = []
    private var bookmarks: [Bookmark] = []
    private var downloads: [DownloadItem] = []
    private var localChapters: [LocalChapterPackage] = []
    private var tracker: [TrackerEntry] = []
    private var scrobblers: [ScrobblerAccount] = ScrobblerKind.allCases.map {
        ScrobblerAccount(kind: $0, username: nil, accessToken: nil, isLinked: false, lastSyncAt: nil)
    }
    private var syncAccount = SyncAccount.default
    private var enabledSourceIDs: Set<String> = ["mock.local", "mock.vi"]
    private var loaded = false

    init(root: URL? = nil) {
        let base = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Usagi", isDirectory: true)
        self.root = base
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Lifecycle

    func prepare() async throws {
        guard !loaded else { return }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        categories = (try? load([FavouriteCategory].self, name: "categories.json")) ?? defaultCategories()
        history = Dictionary(uniqueKeysWithValues: ((try? load([MangaHistoryEntry].self, name: "history.json")) ?? []).map { ($0.manga.id, $0) })
        bookmarks = (try? load([Bookmark].self, name: "bookmarks.json")) ?? []
        downloads = (try? load([DownloadItem].self, name: "downloads.json")) ?? []
        localChapters = (try? load([LocalChapterPackage].self, name: "local_chapters.json")) ?? []
        tracker = (try? load([TrackerEntry].self, name: "tracker.json")) ?? []
        scrobblers = (try? load([ScrobblerAccount].self, name: "scrobblers.json")) ?? scrobblers
        syncAccount = (try? load(SyncAccount.self, name: "sync.json")) ?? .default
        if let sources: [String] = try? load([String].self, name: "sources.json") {
            enabledSourceIDs = Set(sources)
        }
        let mangaList: [Manga] = (try? load([Manga].self, name: "manga_cache.json")) ?? []
        mangaCache = Dictionary(uniqueKeysWithValues: mangaList.map { ($0.id, $0) })
        loaded = true
        AppLog.info("AppDatabase ready at \(root.path)")
    }

    // MARK: - Manga cache

    func cacheManga(_ manga: Manga) throws {
        mangaCache[manga.id] = manga
        try save(Array(mangaCache.values), name: "manga_cache.json")
    }

    func cachedManga(id: Int64) -> Manga? { mangaCache[id] }
    func allCachedManga() -> [Manga] { Array(mangaCache.values) }

    // MARK: - History

    func historyEntries() -> [MangaHistoryEntry] {
        history.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func historyEntry(mangaID: Int64) -> MangaHistoryEntry? { history[mangaID] }

    func upsertHistory(_ entry: MangaHistoryEntry) throws {
        history[entry.manga.id] = entry
        try save(Array(history.values), name: "history.json")
        try cacheManga(entry.manga)
    }

    func removeHistory(mangaID: Int64) throws {
        history.removeValue(forKey: mangaID)
        try save(Array(history.values), name: "history.json")
    }

    func clearHistory() throws {
        history.removeAll()
        try save([MangaHistoryEntry](), name: "history.json")
    }

    // MARK: - Favourites / categories

    func allCategories() -> [FavouriteCategory] {
        categories.sorted { $0.sortKey < $1.sortKey }
    }

    func saveCategories(_ list: [FavouriteCategory]) throws {
        categories = list
        try save(list, name: "categories.json")
    }

    // MARK: - Bookmarks

    func allBookmarks() -> [Bookmark] {
        bookmarks.sorted { $0.createdAt > $1.createdAt }
    }

    func addBookmark(_ bookmark: Bookmark) throws {
        bookmarks.removeAll { $0.mangaID == bookmark.mangaID && $0.chapterID == bookmark.chapterID && $0.page == bookmark.page }
        bookmarks.append(bookmark)
        try save(bookmarks, name: "bookmarks.json")
    }

    func removeBookmark(id: UUID) throws {
        bookmarks.removeAll { $0.id == id }
        try save(bookmarks, name: "bookmarks.json")
    }

    // MARK: - Downloads

    func allDownloads() -> [DownloadItem] {
        downloads.sorted { $0.updatedAt > $1.updatedAt }
    }

    func upsertDownload(_ item: DownloadItem) throws {
        if let i = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[i] = item
        } else {
            downloads.append(item)
        }
        try save(downloads, name: "downloads.json")
    }

    func removeDownload(id: UUID) throws {
        downloads.removeAll { $0.id == id }
        try save(downloads, name: "downloads.json")
    }

    // MARK: - Local chapters

    func allLocalChapters() -> [LocalChapterPackage] { localChapters }

    func upsertLocalChapter(_ package: LocalChapterPackage) throws {
        if let i = localChapters.firstIndex(where: { $0.id == package.id }) {
            localChapters[i] = package
        } else {
            localChapters.append(package)
        }
        try save(localChapters, name: "local_chapters.json")
    }

    func localChapter(mangaID: Int64, chapterID: Int64) -> LocalChapterPackage? {
        localChapters.first { $0.mangaID == mangaID && $0.chapterID == chapterID }
    }

    func removeLocalChapter(id: String) throws {
        localChapters.removeAll { $0.id == id }
        try save(localChapters, name: "local_chapters.json")
    }

    // MARK: - Tracker

    func trackerEntries() -> [TrackerEntry] {
        tracker.sorted { $0.lastCheckedAt > $1.lastCheckedAt }
    }

    func upsertTracker(_ entry: TrackerEntry) throws {
        if let i = tracker.firstIndex(where: { $0.manga.id == entry.manga.id }) {
            tracker[i] = entry
        } else {
            tracker.append(entry)
        }
        try save(tracker, name: "tracker.json")
        try cacheManga(entry.manga)
    }

    func removeTracker(mangaID: Int64) throws {
        tracker.removeAll { $0.manga.id == mangaID }
        try save(tracker, name: "tracker.json")
    }

    // MARK: - Scrobblers / Sync / Sources

    func scrobblerAccounts() -> [ScrobblerAccount] { scrobblers }

    func saveScrobblers(_ list: [ScrobblerAccount]) throws {
        scrobblers = list
        try save(list, name: "scrobblers.json")
    }

    func currentSyncAccount() -> SyncAccount { syncAccount }

    func saveSyncAccount(_ account: SyncAccount) throws {
        syncAccount = account
        try save(account, name: "sync.json")
    }

    func enabledSources() -> Set<String> { enabledSourceIDs }

    func setSourceEnabled(_ id: String, enabled: Bool) throws {
        if enabled { enabledSourceIDs.insert(id) } else { enabledSourceIDs.remove(id) }
        try save(Array(enabledSourceIDs), name: "sources.json")
    }

    // MARK: - Backup snapshot

    func exportPayload(settings: BackupSettingsSnapshot, appVersion: String) -> AppBackupPayload {
        let favManga = Set(categories.flatMap(\.mangaIDs)).compactMap { mangaCache[$0] }
        return AppBackupPayload(
            manifest: BackupManifest(
                version: 1,
                createdAt: Date(),
                appVersion: appVersion,
                platform: "ios",
                mangaCount: mangaCache.count,
                historyCount: history.count,
                favouriteCount: favManga.count,
                bookmarkCount: bookmarks.count
            ),
            favourites: favManga,
            categories: categories,
            history: Array(history.values),
            bookmarks: bookmarks,
            tracker: tracker,
            settings: settings
        )
    }

    func importPayload(_ payload: AppBackupPayload) throws {
        for m in payload.favourites { mangaCache[m.id] = m }
        for h in payload.history { mangaCache[h.manga.id] = h.manga; history[h.manga.id] = h }
        categories = payload.categories
        bookmarks = payload.bookmarks
        tracker = payload.tracker
        try save(Array(mangaCache.values), name: "manga_cache.json")
        try save(Array(history.values), name: "history.json")
        try save(categories, name: "categories.json")
        try save(bookmarks, name: "bookmarks.json")
        try save(tracker, name: "tracker.json")
    }

    func clearCache() throws {
        mangaCache.removeAll()
        try save([Manga](), name: "manga_cache.json")
        let cacheDir = root.appendingPathComponent("image_cache", isDirectory: true)
        try? FileManager.default.removeItem(at: cacheDir)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func storageRoot() -> URL { root }

    func downloadsDirectory() throws -> URL {
        let url = root.appendingPathComponent("downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func importsDirectory() throws -> URL {
        let url = root.appendingPathComponent("imports", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - IO

    private func url(_ name: String) -> URL { root.appendingPathComponent(name) }

    private func save<T: Encodable>(_ value: T, name: String) throws {
        let data = try encoder.encode(value)
        try data.write(to: url(name), options: .atomic)
    }

    private func load<T: Decodable>(_ type: T.Type, name: String) throws -> T {
        let data = try Data(contentsOf: url(name))
        return try decoder.decode(type, from: data)
    }

    private func defaultCategories() -> [FavouriteCategory] {
        [
            FavouriteCategory(id: 1, title: "Reading", sortKey: 0, mangaIDs: []),
            FavouriteCategory(id: 2, title: "Completed", sortKey: 1, mangaIDs: []),
            FavouriteCategory(id: 3, title: "Plan to read", sortKey: 2, mangaIDs: []),
        ]
    }
}
