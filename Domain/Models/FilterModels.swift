import Foundation

struct MangaListFilter: Equatable, Codable, Sendable {
    var query: String = ""
    var tags: [Tag] = []
    var tagsExcluded: [Tag] = []
    var contentRating: [ContentRating] = []
    var states: [MangaPublicationState] = []
    var sortOrder: SortOrder = .popular
    var author: String = ""
    var year: Int? = nil

    var isNotEmpty: Bool {
        !query.isEmpty || !tags.isEmpty || !tagsExcluded.isEmpty ||
        !contentRating.isEmpty || !states.isEmpty ||
        sortOrder != .popular || !author.isEmpty || year != nil
    }

    static let empty = MangaListFilter()
}

enum SortOrder: String, CaseIterable, Identifiable, Codable {
    case popular, updated, newest, rating, name
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .popular: return "Phổ biến"
        case .updated: return "Mới cập nhật"
        case .newest: return "Mới nhất"
        case .rating: return "Đánh giá"
        case .name: return "Tên"
        }
    }
}

struct SavedFilter: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var filter: MangaListFilter

    init(name: String, filter: MangaListFilter) {
        self.id = UUID()
        self.name = name
        self.filter = filter
    }
}
