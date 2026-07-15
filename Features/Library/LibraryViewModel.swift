import Foundation

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published private(set) var categories: [FavouriteCategory] = []
    @Published private(set) var selectedCategoryID: Int64?
    @Published private(set) var items: [Manga] = []
    @Published private(set) var isLoading = false

    private let library: LibraryRepository

    init(library: LibraryRepository) {
        self.library = library
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        categories = await library.categories()
        if selectedCategoryID == nil {
            selectedCategoryID = categories.first?.id
        }
        await reloadItems()
    }

    func selectCategory(_ id: Int64?) async {
        selectedCategoryID = id
        await reloadItems()
    }

    func createCategory(_ title: String) async -> FavouriteCategory? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let cat = await library.createCategory(title: trimmed)
        await load()
        return cat
    }

    private func reloadItems() async {
        if let selectedCategoryID {
            items = await library.manga(in: selectedCategoryID)
        } else {
            items = await library.allFavourites()
        }
    }
}
