import Foundation

actor MockMangaRepository: MangaRepository {
    private let catalog: [Manga]
    private let sourceList: [MangaSource]

    init(catalog: [Manga] = MockData.manga, sources: [MangaSource] = MockData.sources) {
        self.catalog = catalog
        self.sourceList = sources
    }

    func popular(sourceID: String?) async throws -> [Manga] {
        try await latency()
        return filter(sourceID: sourceID).sorted { $0.rating > $1.rating }
    }

    func latest(sourceID: String?) async throws -> [Manga] {
        try await latency()
        return filter(sourceID: sourceID).reversed()
    }

    func search(query: String, sourceID: String?) async throws -> [Manga] {
        try await latency(ms: 250)
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return try await popular(sourceID: sourceID) }
        return filter(sourceID: sourceID).filter { manga in
            manga.title.lowercased().contains(q)
                || manga.altTitles.contains { $0.lowercased().contains(q) }
                || manga.authors.contains { $0.lowercased().contains(q) }
                || manga.tags.contains { $0.title.lowercased().contains(q) }
        }
    }

    func details(id: Int64) async throws -> Manga {
        try await latency(ms: 200)
        guard let manga = catalog.first(where: { $0.id == id }) else {
            throw MangaRepositoryError.notFound
        }
        return manga
    }

    func chapters(mangaID: Int64) async throws -> [Chapter] {
        try await latency(ms: 150)
        guard let manga = catalog.first(where: { $0.id == mangaID }) else {
            throw MangaRepositoryError.notFound
        }
        return manga.chapters
    }

    func pages(chapterID: Int64) async throws -> [Page] {
        try await latency(ms: 180)
        for manga in catalog {
            if let chapter = manga.chapters.first(where: { $0.id == chapterID }) {
                return chapter.pages
            }
        }
        throw MangaRepositoryError.notFound
    }

    func sources() async throws -> [MangaSource] {
        try await latency(ms: 50)
        return sourceList
    }

    private func filter(sourceID: String?) -> [Manga] {
        guard let sourceID else { return catalog }
        return catalog.filter { $0.sourceID == sourceID }
    }

    private func latency(ms: UInt64 = 350) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }
}

enum MangaRepositoryError: LocalizedError {
    case notFound
    case network
    case cloudflareBlocked
    case unsupportedSource

    var errorDescription: String? {
        switch self {
        case .notFound: return "Manga not found."
        case .network: return "Network error. Check your connection."
        case .cloudflareBlocked: return "Cloudflare protection blocked this request."
        case .unsupportedSource: return "This source is not supported yet."
        }
    }
}
