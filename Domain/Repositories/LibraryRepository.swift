import Foundation

protocol LibraryRepository: Sendable {
    func categories() async -> [FavouriteCategory]
    func manga(in categoryID: Int64) async -> [Manga]
    func allFavourites() async -> [Manga]
    func isFavourite(mangaID: Int64) async -> Bool
    func toggleFavourite(manga: Manga, categoryID: Int64?) async
    func createCategory(title: String) async -> FavouriteCategory
}
