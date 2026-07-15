import Foundation

protocol MangaRepository: Sendable {
    func popular(sourceID: String?) async throws -> [Manga]
    func latest(sourceID: String?) async throws -> [Manga]
    func search(query: String, sourceID: String?) async throws -> [Manga]
    func details(id: Int64) async throws -> Manga
    func chapters(mangaID: Int64) async throws -> [Chapter]
    func pages(chapterID: Int64) async throws -> [Page]
    func sources() async throws -> [MangaSource]
}
