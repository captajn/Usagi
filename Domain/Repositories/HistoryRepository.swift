import Foundation

protocol HistoryRepository: Sendable {
    func entries() async -> [MangaHistoryEntry]
    func entry(mangaID: Int64) async -> MangaHistoryEntry?
    func upsert(manga: Manga, chapterID: Int64?, page: Int, percent: Float) async
    func remove(mangaID: Int64) async
    func clear() async
}
