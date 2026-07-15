import Foundation

/// Wraps a remote/mock source repository with DB cache — mirrors Android CachingMangaRepository.
actor CachingMangaRepository: MangaRepository {
    private let remote: MangaRepository
    private let db: AppDatabase
    private var memoryDetails: [Int64: Manga] = [:]
    private var memoryLists: [String: [Manga]] = [:]

    init(remote: MangaRepository, db: AppDatabase = .shared) {
        self.remote = remote
        self.db = db
    }

    func popular(sourceID: String?) async throws -> [Manga] {
        let key = "popular:\(sourceID ?? "all")"
        if let cached = memoryLists[key] { return try await filterEnabled(cached) }
        let list = try await remote.popular(sourceID: sourceID)
        memoryLists[key] = list
        for m in list { try? await db.cacheManga(m) }
        return try await filterEnabled(list)
    }

    func latest(sourceID: String?) async throws -> [Manga] {
        let key = "latest:\(sourceID ?? "all")"
        if let cached = memoryLists[key] { return try await filterEnabled(cached) }
        let list = try await remote.latest(sourceID: sourceID)
        memoryLists[key] = list
        for m in list { try? await db.cacheManga(m) }
        return try await filterEnabled(list)
    }

    func search(query: String, sourceID: String?) async throws -> [Manga] {
        let list = try await remote.search(query: query, sourceID: sourceID)
        for m in list { try? await db.cacheManga(m) }
        return try await filterEnabled(list)
    }

    func details(id: Int64) async throws -> Manga {
        if let mem = memoryDetails[id] { return mem }
        if let disk = await db.cachedManga(id: id), !disk.chapters.isEmpty {
            memoryDetails[id] = disk
            return disk
        }
        let manga = try await remote.details(id: id)
        memoryDetails[id] = manga
        try? await db.cacheManga(manga)
        return manga
    }

    func chapters(mangaID: Int64) async throws -> [Chapter] {
        try await details(id: mangaID).chapters
    }

    func pages(chapterID: Int64) async throws -> [Page] {
        // Prefer local offline package
        let locals = await db.allLocalChapters()
        if let local = locals.first(where: { $0.chapterID == chapterID }) {
            return local.pagePaths.enumerated().map { idx, path in
                Page(id: Int64(idx), index: idx, url: path.hasPrefix("http") ? path : "file://\(path)")
            }
        }
        return try await remote.pages(chapterID: chapterID)
    }

    func sources() async throws -> [MangaSource] {
        let all = try await remote.sources()
        let enabled = await db.enabledSources()
        return all.map { source in
            var s = source
            s.isEnabled = enabled.contains(source.id)
            return s
        }
    }

    private func filterEnabled(_ list: [Manga]) async throws -> [Manga] {
        let enabled = await db.enabledSources()
        if enabled.isEmpty { return list }
        return list.filter { enabled.contains($0.sourceID) }
    }
}
