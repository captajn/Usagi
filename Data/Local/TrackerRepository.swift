import Foundation

protocol TrackerRepository: Sendable {
    func entries() async -> [TrackerEntry]
    func track(manga: Manga) async
    func untrack(mangaID: Int64) async
    func refreshAll(using mangaRepository: MangaRepository) async
    func markSeen(mangaID: Int64) async
}

actor PersistentTrackerRepository: TrackerRepository {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    func entries() async -> [TrackerEntry] {
        await db.trackerEntries()
    }

    func track(manga: Manga) async {
        let entry = TrackerEntry(
            id: UUID(),
            manga: manga,
            lastKnownChapters: manga.chapterCount,
            newChapters: 0,
            lastCheckedAt: Date(),
            isNotifying: true
        )
        try? await db.upsertTracker(entry)
        try? await db.cacheManga(manga)
    }

    func untrack(mangaID: Int64) async {
        try? await db.removeTracker(mangaID: mangaID)
    }

    func refreshAll(using mangaRepository: MangaRepository) async {
        let current = await db.trackerEntries()
        for entry in current {
            do {
                let fresh = try await mangaRepository.details(id: entry.manga.id)
                var updated = entry
                let delta = max(0, fresh.chapterCount - entry.lastKnownChapters)
                updated.manga = fresh
                updated.newChapters = delta
                updated.lastCheckedAt = Date()
                // Keep lastKnown until user marks seen; if first track, no spam
                try? await db.upsertTracker(updated)
            } catch {
                AppLog.error("Tracker refresh failed for \(entry.manga.title)", error: error)
            }
        }
    }

    func markSeen(mangaID: Int64) async {
        guard var entry = await db.trackerEntries().first(where: { $0.manga.id == mangaID }) else { return }
        entry.lastKnownChapters = entry.manga.chapterCount
        entry.newChapters = 0
        entry.lastCheckedAt = Date()
        try? await db.upsertTracker(entry)
    }
}

actor ScrobblingService {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    func accounts() async -> [ScrobblerAccount] {
        await db.scrobblerAccounts()
    }

    func link(kind: ScrobblerKind, username: String) async throws {
        // OAuth stub — real ASWebAuthenticationSession hooks in UI
        var list = await db.scrobblerAccounts()
        guard let i = list.firstIndex(where: { $0.kind == kind }) else { return }
        list[i].isLinked = true
        list[i].username = username
        list[i].accessToken = "stub-\(UUID().uuidString)"
        list[i].lastSyncAt = Date()
        try await db.saveScrobblers(list)
    }

    func unlink(kind: ScrobblerKind) async throws {
        var list = await db.scrobblerAccounts()
        guard let i = list.firstIndex(where: { $0.kind == kind }) else { return }
        list[i] = ScrobblerAccount(kind: kind, username: nil, accessToken: nil, isLinked: false, lastSyncAt: nil)
        try await db.saveScrobblers(list)
    }

    func scrobble(manga: Manga, chapterNumber: Double) async {
        let linked = await db.scrobblerAccounts().filter(\.isLinked)
        for account in linked {
            AppLog.info("Scrobble \(manga.title) ch \(chapterNumber) → \(account.kind.displayName)")
        }
    }
}
