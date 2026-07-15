import Foundation

actor InMemoryHistoryRepository: HistoryRepository {
    private var storage: [Int64: MangaHistoryEntry] = [:]

    func entries() async -> [MangaHistoryEntry] {
        storage.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    func entry(mangaID: Int64) async -> MangaHistoryEntry? {
        storage[mangaID]
    }

    func upsert(manga: Manga, chapterID: Int64?, page: Int, percent: Float) async {
        storage[manga.id] = MangaHistoryEntry(
            manga: manga,
            chapterID: chapterID,
            page: page,
            percent: percent,
            updatedAt: Date()
        )
    }

    func remove(mangaID: Int64) async {
        storage.removeValue(forKey: mangaID)
    }

    func clear() async {
        storage.removeAll()
    }
}
