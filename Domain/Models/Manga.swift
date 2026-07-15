import Foundation

struct Manga: Identifiable, Hashable, Codable, Sendable {
    let id: Int64
    var title: String
    var altTitles: [String]
    var url: String
    var publicURL: String
    var rating: Float
    var isNSFW: Bool
    var contentRating: ContentRating
    var coverURL: String?
    var largeCoverURL: String?
    var state: MangaPublicationState
    var authors: [String]
    var sourceID: String
    var description: String
    var tags: [Tag]
    var chapters: [Chapter]

    var authorsText: String {
        authors.isEmpty ? "Unknown author" : authors.joined(separator: ", ")
    }

    var ratingText: String {
        guard rating >= 0 else { return "—" }
        return String(format: "%.1f", rating * 10)
    }

    var chapterCount: Int { chapters.count }

    static func == (lhs: Manga, rhs: Manga) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Tag: Identifiable, Hashable, Codable, Sendable {
    let id: Int64
    var title: String
    var key: String
    var sourceID: String
}

struct Chapter: Identifiable, Hashable, Codable, Sendable {
    let id: Int64
    var mangaID: Int64
    var name: String
    var number: Double
    var volume: Double?
    var branch: String?
    var uploadDate: Date?
    var scanlator: String?
    var url: String
    var sourceID: String
    /// Page image URLs (remote or asset placeholders for mock).
    var pages: [Page]

    var displayTitle: String {
        if number > 0 {
            let n = number == floor(number) ? String(Int(number)) : String(number)
            return "Ch. \(n)\(name.isEmpty ? "" : " — \(name)")"
        }
        return name.isEmpty ? "Chapter" : name
    }
}

struct Page: Identifiable, Hashable, Codable, Sendable {
    let id: Int64
    var index: Int
    var url: String
    var previewURL: String?

    init(id: Int64, index: Int, url: String, previewURL: String? = nil) {
        self.id = id
        self.index = index
        self.url = url
        self.previewURL = previewURL
    }
}

struct MangaSource: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var locale: String
    var isEnabled: Bool
    var isNsfw: Bool

    var displayLocale: String { locale.uppercased() }
}

struct FavouriteCategory: Identifiable, Hashable, Codable, Sendable {
    let id: Int64
    var title: String
    var sortKey: Int
    var mangaIDs: [Int64]
}

struct MangaHistoryEntry: Identifiable, Hashable, Codable, Sendable {
    var id: Int64 { manga.id }
    var manga: Manga
    var chapterID: Int64?
    var page: Int
    var percent: Float
    var updatedAt: Date
}

struct Bookmark: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var mangaID: Int64
    var chapterID: Int64
    var page: Int
    var createdAt: Date
    var percent: Float
}
