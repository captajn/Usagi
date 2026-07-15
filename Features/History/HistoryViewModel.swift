import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [MangaHistoryEntry] = []
    @Published private(set) var isLoading = false

    private let history: HistoryRepository

    init(history: HistoryRepository) {
        self.history = history
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        entries = await history.entries()
    }

    func remove(_ entry: MangaHistoryEntry) async {
        await history.remove(mangaID: entry.manga.id)
        await load()
    }

    func clear() async {
        await history.clear()
        await load()
    }

    func progressText(for entry: MangaHistoryEntry) -> String {
        let percent = Int((entry.percent * 100).rounded())
        if let chapterID = entry.chapterID {
            return "Ch. id \(chapterID) · page \(entry.page + 1) · \(percent)%"
        }
        return "Page \(entry.page + 1) · \(percent)%"
    }
}
