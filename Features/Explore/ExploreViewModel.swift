import Foundation
import SwiftUI

@MainActor
final class ExploreViewModel: ObservableObject {
    @Published private(set) var popular: [Manga] = []
    @Published private(set) var latest: [Manga] = []
    @Published private(set) var sources: [MangaSource] = []
    @Published var selectedSourceID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let repository: MangaRepository

    init(repository: MangaRepository) {
        self.repository = repository
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let sourcesTask = repository.sources()
            async let popularTask = repository.popular(sourceID: selectedSourceID)
            async let latestTask = repository.latest(sourceID: selectedSourceID)
            sources = try await sourcesTask
            popular = try await popularTask
            latest = try await latestTask
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectSource(_ id: String?) async {
        selectedSourceID = id
        await load()
    }
}
