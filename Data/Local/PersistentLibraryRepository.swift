import Foundation

actor PersistentLibraryRepository: LibraryRepository {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    func categories() async -> [FavouriteCategory] {
        await db.allCategories()
    }

    func manga(in categoryID: Int64) async -> [Manga] {
        let cats = await db.allCategories()
        guard let category = cats.first(where: { $0.id == categoryID }) else { return [] }
        return await resolve(ids: category.mangaIDs)
    }

    func allFavourites() async -> [Manga] {
        let ids = Set(await db.allCategories().flatMap(\.mangaIDs))
        return await resolve(ids: Array(ids)).sorted { $0.title < $1.title }
    }

    func isFavourite(mangaID: Int64) async -> Bool {
        await db.allCategories().contains { $0.mangaIDs.contains(mangaID) }
    }

    func toggleFavourite(manga: Manga, categoryID: Int64?) async {
        try? await db.cacheManga(manga)
        var cats = await db.allCategories()
        let targetID = categoryID ?? cats.first?.id
        guard let targetID, let index = cats.firstIndex(where: { $0.id == targetID }) else { return }

        if cats.contains(where: { $0.mangaIDs.contains(manga.id) }) {
            for i in cats.indices {
                cats[i].mangaIDs.removeAll { $0 == manga.id }
            }
        } else {
            for i in cats.indices {
                cats[i].mangaIDs.removeAll { $0 == manga.id }
            }
            cats[index].mangaIDs.append(manga.id)
        }
        try? await db.saveCategories(cats)
    }

    func createCategory(title: String) async -> FavouriteCategory {
        var cats = await db.allCategories()
        let nextID = (cats.map(\.id).max() ?? 0) + 1
        let category = FavouriteCategory(id: nextID, title: title, sortKey: cats.count, mangaIDs: [])
        cats.append(category)
        try? await db.saveCategories(cats)
        return category
    }

    private func resolve(ids: [Int64]) async -> [Manga] {
        var result: [Manga] = []
        for id in ids {
            if let m = await db.cachedManga(id: id) {
                result.append(m)
            }
        }
        return result
    }
}
