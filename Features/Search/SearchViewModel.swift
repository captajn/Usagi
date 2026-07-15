import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var results: [Manga] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSearch = false

    private let repository: MangaRepository
    private var searchTask: Task<Void, Never>?

    init(repository: MangaRepository) {
        self.repository = repository
    }

    func onQueryChanged(_ newValue: String) {
        query = newValue
        searchTask?.cancel()
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 1 else {
            results = []
            didSearch = false
            errorMessage = nil
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            await search(trimmed)
        }
    }

    func search(_ q: String? = nil) async {
        let term = (q ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        didSearch = true
        defer { isLoading = false }
        do {
            results = try await repository.search(query: term, sourceID: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
