import Foundation

actor InMemoryLibraryRepository: LibraryRepository {
    private var categories: [FavouriteCategory]
    private var mangaByID: [Int64: Manga] = [:]

    init() {
        categories = [
            FavouriteCategory(id: 1, title: "Reading", sortKey: 0, mangaIDs: []),
            FavouriteCategory(id: 2, title: "Completed", sortKey: 1, mangaIDs: []),
            FavouriteCategory(id: 3, title: "Plan to read", sortKey: 2, mangaIDs: []),
        ]
    }

    func categories() async -> [FavouriteCategory] {
        categories.sorted { $0.sortKey < $1.sortKey }
    }

    func manga(in categoryID: Int64) async -> [Manga] {
        guard let category = categories.first(where: { $0.id == categoryID }) else { return [] }
        return category.mangaIDs.compactMap { mangaByID[$0] }
    }

    func allFavourites() async -> [Manga] {
        let ids = Set(categories.flatMap(\.mangaIDs))
        return ids.compactMap { mangaByID[$0] }.sorted { $0.title < $1.title }
    }

    func isFavourite(mangaID: Int64) async -> Bool {
        categories.contains { $0.mangaIDs.contains(mangaID) }
    }

    func toggleFavourite(manga: Manga, categoryID: Int64?) async {
        mangaByID[manga.id] = manga
        if let categoryID,
           let index = categories.firstIndex(where: { $0.id == categoryID }) {
            if categories[index].mangaIDs.contains(manga.id) {
                categories[index].mangaIDs.removeAll { $0 == manga.id }
            } else {
                // Remove from other categories first (single category for MVP).
                for i in categories.indices {
                    categories[i].mangaIDs.removeAll { $0 == manga.id }
                }
                categories[index].mangaIDs.append(manga.id)
            }
            return
        }

        // Default: toggle in first category.
        guard !categories.isEmpty else { return }
        if await isFavourite(mangaID: manga.id) {
            for i in categories.indices {
                categories[i].mangaIDs.removeAll { $0 == manga.id }
            }
        } else {
            categories[0].mangaIDs.append(manga.id)
        }
    }

    func createCategory(title: String) async -> FavouriteCategory {
        let nextID = (categories.map(\.id).max() ?? 0) + 1
        let category = FavouriteCategory(
            id: nextID,
            title: title,
            sortKey: categories.count,
            mangaIDs: []
        )
        categories.append(category)
        return category
    }
}
