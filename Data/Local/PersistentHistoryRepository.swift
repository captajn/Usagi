import Foundation

actor PersistentHistoryRepository: HistoryRepository {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    func entries() async -> [MangaHistoryEntry] {
        await db.historyEntries()
    }

    func entry(mangaID: Int64) async -> MangaHistoryEntry? {
        await db.historyEntry(mangaID: mangaID)
    }

    func upsert(manga: Manga, chapterID: Int64?, page: Int, percent: Float) async {
        let entry = MangaHistoryEntry(
            manga: manga,
            chapterID: chapterID,
            page: page,
            percent: percent,
            updatedAt: Date()
        )
        try? await db.upsertHistory(entry)
    }

    func remove(mangaID: Int64) async {
        try? await db.removeHistory(mangaID: mangaID)
    }

    func clear() async {
        try? await db.clearHistory()
    }
}
