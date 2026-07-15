import Foundation

/// MangaDex implementation of MangaRepository protocol.
actor MangaDexRepository: MangaRepository {
    private let api = MangaDexAPI()
    private var chapterRemoteIDs: [Int64: String] = [:]

    // MARK: - MangaRepository

    func popular(sourceID: String?) async throws -> [Manga] {
        let list = try await api.mangaList(offset: 0, limit: 30, order: .followedCount)
        return list.map { $0.toManga(sourceID: "mangadex") }
    }

    func latest(sourceID: String?) async throws -> [Manga] {
        let list = try await api.mangaList(offset: 0, limit: 30, order: .latestUpload)
        return list.map { $0.toManga(sourceID: "mangadex") }
    }

    func search(query: String, sourceID: String?) async throws -> [Manga] {
        let list = try await api.mangaList(offset: 0, limit: 30, query: query)
        return list.map { $0.toManga(sourceID: "mangadex") }
    }

    func details(id: Int64) async throws -> Manga {
        let detail = try await api.mangaDetail(id: String(id))
        var manga = detail.toManga(sourceID: "mangadex")
        let chapters = try await chapters(mangaID: id)
        manga.chapters = chapters
        return manga
    }

    func chapters(mangaID: Int64) async throws -> [Chapter] {
        let list = try await api.chapters(mangaID: String(mangaID))
        var chapters: [Chapter] = []
        for (index, ch) in list.enumerated() {
            let localID = Int64(ch.id.hashValue) &* Int64(index + 1)
            chapterRemoteIDs[localID] = ch.id
            chapters.append(Chapter(
                id: localID,
                mangaID: mangaID,
                name: ch.attributes.title ?? "",
                number: Double(ch.attributes.chapter ?? "") ?? Double(index),
                volume: Double(ch.attributes.volume ?? ""),
                branch: nil,
                uploadDate: ISO8601DateFormatter().date(from: ch.attributes.publishAt ?? ""),
                scanlator: ch.relationships?.first(where: { $0.type == "scanlation_group" })?.attributes?.name,
                url: "/chapter/\(ch.id)",
                sourceID: "mangadex",
                pages: []
            ))
        }
        return chapters
    }

    func pages(chapterID: Int64) async throws -> [Page] {
        guard let remoteID = chapterRemoteIDs[chapterID] else { return [] }
        let list = try await api.pages(chapterID: remoteID)
        return list.map { page in
            Page(id: Int64(page.index), index: page.index, url: page.url, previewURL: page.previewURL)
        }
    }

    func sources() async throws -> [MangaSource] {
        [MangaSource(id: "mangadex", title: "MangaDex", locale: "EN", isEnabled: true, isNsfw: false)]
    }
}

// MARK: - Mapping

private struct MangaDexPage {
    let index: Int
    let url: String
    let previewURL: String?
}

extension MangaDexManga {
    func toManga(sourceID: String) -> Manga {
        let idInt = Int64(id.hashValue)
        return Manga(
            id: idInt,
            title: attributes.localizedTitle,
            altTitles: attributes.localizedAltTitles,
            url: "/manga/\(id)",
            publicURL: "https://mangadex.org/title/\(id)",
            rating: 0,
            isNSFW: attributes.contentRating == "pornographic" || attributes.contentRating == "erotica",
            contentRating: mapContentRating(attributes.contentRating),
            coverURL: coverURL,
            largeCoverURL: largeCoverURL,
            state: mapStatus(attributes.status),
            authors: authorName.map { [$0] } ?? [],
            sourceID: sourceID,
            description: attributes.localizedDescription,
            tags: (attributes.tags ?? []).compactMap { tag in
                guard let name = tag.attributes?.localizedName, !name.isEmpty else { return nil }
                return Tag(id: Int64(tag.id.hashValue), title: name, key: tag.id, sourceID: sourceID)
            },
            chapters: []
        )
    }

    private func mapContentRating(_ rating: String?) -> ContentRating {
        switch rating {
        case "safe": return .safe
        case "suggestive": return .suggestive
        case "erotica", "pornographic": return .adult
        default: return .safe
        }
    }

    private func mapStatus(_ status: String?) -> MangaPublicationState {
        switch status {
        case "ongoing": return .ongoing
        case "completed": return .finished
        case "hiatus": return .paused
        case "cancelled": return .abandoned
        default: return .unknown
        }
    }
}
