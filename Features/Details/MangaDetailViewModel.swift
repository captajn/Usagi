import Foundation

@MainActor
final class MangaDetailViewModel: ObservableObject {
    @Published private(set) var manga: Manga?
    @Published private(set) var related: [Manga] = []
    @Published private(set) var isFavourite = false
    @Published private(set) var isTracked = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var history: MangaHistoryEntry?
    @Published private(set) var readingTime: ReadingTimeEstimate?
    @Published var downloadMessage: String?

    let mangaID: Int64
    private let mangaRepository: MangaRepository
    private let library: LibraryRepository
    private let historyRepository: HistoryRepository
    private let trackerRepository: TrackerRepository
    private let downloadRepository: DownloadRepository
    private let settings: UserDefaultsSettingsStore

    init(
        mangaID: Int64,
        mangaRepository: MangaRepository,
        library: LibraryRepository,
        history: HistoryRepository,
        trackerRepository: TrackerRepository,
        downloadRepository: DownloadRepository,
        settings: UserDefaultsSettingsStore
    ) {
        self.mangaID = mangaID
        self.mangaRepository = mangaRepository
        self.library = library
        self.historyRepository = history
        self.trackerRepository = trackerRepository
        self.downloadRepository = downloadRepository
        self.settings = settings
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let details = try await mangaRepository.details(id: mangaID)
            manga = details
            isFavourite = await library.isFavourite(mangaID: mangaID)
            history = await historyRepository.entry(mangaID: mangaID)
            let tracked = await trackerRepository.entries()
            isTracked = tracked.contains { $0.manga.id == mangaID }
            let pages = details.chapters.reduce(0) { $0 + $1.pages.count }
            var estimate = ReadingTimeEstimate.estimate(pages: max(pages, details.chapterCount * 8))
            estimate.chapterCount = details.chapterCount
            readingTime = estimate

            let popular = try await mangaRepository.popular(sourceID: details.sourceID)
            let tagKeys = Set(details.tags.map(\.key))
            related = popular
                .filter { $0.id != details.id }
                .filter { m in m.tags.contains { tagKeys.contains($0.key) } || m.sourceID == details.sourceID }
                .prefix(8)
                .map { $0 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavourite() async {
        guard let manga else { return }
        await library.toggleFavourite(manga: manga, categoryID: nil)
        isFavourite = await library.isFavourite(mangaID: manga.id)
    }

    func toggleTrack() async {
        guard let manga else { return }
        if isTracked {
            await trackerRepository.untrack(mangaID: manga.id)
            isTracked = false
        } else {
            await trackerRepository.track(manga: manga)
            isTracked = true
        }
    }

    func download(chapter: Chapter) async {
        guard let manga else { return }
        _ = await downloadRepository.enqueue(manga: manga, chapter: chapter)
        downloadMessage = String(localized: "Queued \(chapter.displayTitle)")
    }

    func continueChapter() -> Chapter? {
        guard let manga else { return nil }
        if let history,
           let chapterID = history.chapterID,
           let chapter = manga.chapters.first(where: { $0.id == chapterID }) {
            return chapter
        }
        return manga.chapters.first
    }
}
