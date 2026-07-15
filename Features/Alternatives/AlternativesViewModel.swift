import Foundation

@MainActor
final class AlternativesViewModel: ObservableObject {
    @Published private(set) var alternatives: [Manga] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published var searchAllSources = false

    let manga: Manga
    private let mangaRepository: MangaRepository
    private let database: AppDatabase

    init(manga: Manga, mangaRepository: MangaRepository, database: AppDatabase) {
        self.manga = manga
        self.mangaRepository = mangaRepository
        self.database = database
    }

    func search() async {
        isLoading = true
        errorMessage = nil

        do {
            let allSources = try await mangaRepository.sources()
            let enabledSourceIDs = await database.enabledSources()
            let sources = searchAllSources
                ? allSources
                : allSources.filter { enabledSourceIDs.contains($0.id) }

            var results: [Manga] = []
            for source in sources where source.id != manga.sourceID {
                let found = try await mangaRepository.search(query: manga.title, sourceID: source.id)
                results.append(contentsOf: found)
            }
            alternatives = results
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func migrate(to target: Manga) async {
        do {
            if var entry = await database.historyEntry(mangaID: manga.id) {
                entry.manga = target
                try await database.upsertHistory(entry)
                try await database.removeHistory(mangaID: manga.id)
            }

            var cats = await database.allCategories()
            for i in cats.indices {
                if cats[i].mangaIDs.contains(manga.id) {
                    cats[i].mangaIDs.removeAll { $0 == manga.id }
                    if !cats[i].mangaIDs.contains(target.id) {
                        cats[i].mangaIDs.append(target.id)
                    }
                }
            }
            try await database.saveCategories(cats)
            try await database.cacheManga(target)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
