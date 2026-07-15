import Foundation

/// MangaDex REST API client (https://api.mangadex.org/docs/)
struct MangaDexAPI {
    static let base = "https://api.mangadex.org"
    static let imageBase = "https://uploads.mangadex.org"

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    // MARK: - Manga list

    func mangaList(offset: Int = 0, limit: Int = 20, order: MangaDexOrder = .followedCount, tags: [String] = [], query: String? = nil) async throws -> [MangaDexManga] {
        var components = URLComponents(string: "\(MangaDexAPI.base)/manga")!
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "order[\(order.key)]", value: "desc"),
            URLQueryItem(name: "availableTranslatedLanguage[]", value: "en"),
            URLQueryItem(name: "availableTranslatedLanguage[]", value: "vi"),
        ]
        for tag in tags {
            queryItems.append(URLQueryItem(name: "includedTags[]", value: tag))
        }
        if let query, !query.isEmpty {
            queryItems.append(URLQueryItem(name: "title", value: query))
        }
        components.queryItems = queryItems

        let data = try await fetch(components.url!)
        let response = try decoder.decode(MangaDexListResponse.self, from: data)
        return response.data
    }

    // MARK: - Manga detail

    func mangaDetail(id: String) async throws -> MangaDexManga {
        var components = URLComponents(string: "\(MangaDexAPI.base)/manga/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "includes[]", value: "cover_art"),
            URLQueryItem(name: "includes[]", value: "author"),
        ]
        let data = try await fetch(components.url!)
        let response = try decoder.decode(MangaDexSingleResponse.self, from: data)
        return response.data
    }

    // MARK: - Chapters

    func chapters(mangaID: String, offset: Int = 0, limit: Int = 100) async throws -> [MangaDexChapter] {
        var components = URLComponents(string: "\(MangaDexAPI.base)/manga/\(mangaID)/feed")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "order[chapter]", value: "desc"),
            URLQueryItem(name: "includes[]", value: "scanlation_group"),
            URLQueryItem(name: "translatedLanguage[]", value: "en"),
            URLQueryItem(name: "translatedLanguage[]", value: "vi"),
        ]
        let data = try await fetch(components.url!)
        let response = try decoder.decode(MangaDexChapterResponse.self, from: data)
        return response.data
    }

    // MARK: - Pages

    func pages(chapterID: String) async throws -> [MangaDexPage] {
        let url = URL(string: "\(MangaDexAPI.base)/at-home/server/\(chapterID)")!
        let data = try await fetch(url)
        let response = try decoder.decode(MangaDexAtHomeResponse.self, from: data)
        return response.chapter.data.enumerated().map { index, filename in
            MangaDexPage(
                index: index,
                url: "\(response.baseUrl)/data/\(response.chapter.hash)/\(filename)",
                previewURL: "\(response.baseUrl)/data/\(response.chapter.hash)/\(response.chapter.dataVeryLow?[safe: index] ?? filename)"
            )
        }
    }

    // MARK: - Tags

    func tags() async throws -> [MangaDexTag] {
        let url = URL(string: "\(MangaDexAPI.base)/manga/tag")!
        let data = try await fetch(url)
        let response = try decoder.decode(MangaDexTagResponse.self, from: data)
        return response.data
    }

    // MARK: - Network

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Usagi/0.1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MangaDexError.serverError
        }
        return data
    }
}

// MARK: - Errors

enum MangaDexError: Error, LocalizedError {
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .serverError: return "MangaDex server error"
        case .decodingError: return "Failed to decode response"
        }
    }
}

// MARK: - Order

enum MangaDexOrder: String {
    case followedCount, rating, latestUpload, title

    var key: String {
        switch self {
        case .followedCount: return "followedCount"
        case .rating: return "rating"
        case .latestUpload: return "latestUploadedChapter"
        case .title: return "title"
        }
    }
}

// MARK: - API Response Models

struct MangaDexListResponse: Decodable {
    let data: [MangaDexManga]
    let limit: Int
    let offset: Int
    let total: Int
}

struct MangaDexSingleResponse: Decodable {
    let data: MangaDexManga
}

struct MangaDexManga: Decodable {
    let id: String
    let attributes: MangaDexAttributes
    let relationships: [MangaDexRelationship]?

    var coverURL: String? {
        relationships?.first(where: { $0.type == "cover_art" })?.attributes?.fileName
            .map { "\(MangaDexAPI.imageBase)/covers/\(id)/\($0).256.jpg" }
    }

    var largeCoverURL: String? {
        relationships?.first(where: { $0.type == "cover_art" })?.attributes?.fileName
            .map { "\(MangaDexAPI.imageBase)/covers/\(id)/\($0).512.jpg" }
    }

    var authorName: String? {
        relationships?.first(where: { $0.type == "author" })?.attributes?.name
    }
}

struct MangaDexAttributes: Decodable {
    let title: [String: String]
    let altTitles: [[String: String]]?
    let description: [String: String]?
    let tags: [MangaDexTag]?
    let status: String?
    let year: Int?
    let contentRating: String?
    let lastChapter: String?
    let lastVolume: String?

    var localizedTitle: String {
        if let en = title["en"] { return en }
        if let ja = title["ja"] ?? title["ja-ro"] { return ja }
        return title.values.first ?? "Unknown"
    }

    var localizedAltTitles: [String] {
        (altTitles ?? []).compactMap { $0["en"] ?? $0["ja"] ?? $0.values.first }
    }

    var localizedDescription: String {
        description?["en"] ?? description?.values.first ?? ""
    }
}

struct MangaDexTag: Decodable {
    let id: String
    let attributes: MangaDexTagAttributes?
}

struct MangaDexTagAttributes: Decodable {
    let name: [String: String]
    let group: String?

    var localizedName: String {
        name["en"] ?? name.values.first ?? ""
    }
}

struct MangaDexRelationship: Decodable {
    let id: String
    let type: String
    let attributes: MangaDexRelationshipAttributes?
}

struct MangaDexRelationshipAttributes: Decodable {
    let fileName: String?
    let name: String?
}

// MARK: - Chapter

struct MangaDexChapterResponse: Decodable {
    let data: [MangaDexChapter]
    let limit: Int
    let offset: Int
    let total: Int
}

struct MangaDexChapter: Decodable {
    let id: String
    let attributes: MangaDexChapterAttributes
    let relationships: [MangaDexRelationship]?
}

struct MangaDexChapterAttributes: Decodable {
    let title: String?
    let chapter: String?
    let volume: String?
    let translatedLanguage: String?
    let publishAt: String?
    let pages: Int?
}

// MARK: - Pages

struct MangaDexAtHomeResponse: Decodable {
    let baseUrl: String
    let chapter: MangaDexAtHomeChapter
}

struct MangaDexAtHomeChapter: Decodable {
    let hash: String
    let data: [String]
    let dataVeryLow: [String]?
}

// MARK: - Tag list

struct MangaDexTagResponse: Decodable {
    let data: [MangaDexTag]
}
