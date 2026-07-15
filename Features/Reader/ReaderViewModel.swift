import Foundation
import UIKit
import Photos

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published private(set) var pages: [Page] = []
    @Published var currentIndex: Int = 0
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showsControls = true
    @Published var chapter: Chapter

    let manga: Manga
    private let mangaRepository: MangaRepository
    private let historyRepository: HistoryRepository
    private let bookmarkRepository: BookmarkRepository
    private let scrobblingService: ScrobblingService
    private let settings: UserDefaultsSettingsStore
    private let initialPage: Int

    var progress: Float {
        guard pages.count > 1 else { return pages.isEmpty ? 0 : 1 }
        return Float(currentIndex) / Float(pages.count - 1)
    }

    var pageLabel: String {
        guard !pages.isEmpty else { return "—" }
        return "\(currentIndex + 1) / \(pages.count)"
    }

    var readerMode: ReaderMode { settings.readerMode }

    init(
        manga: Manga,
        chapter: Chapter,
        initialPage: Int,
        mangaRepository: MangaRepository,
        historyRepository: HistoryRepository,
        bookmarkRepository: BookmarkRepository,
        scrobblingService: ScrobblingService,
        settings: UserDefaultsSettingsStore
    ) {
        self.manga = manga
        self.chapter = chapter
        self.initialPage = max(0, initialPage)
        self.mangaRepository = mangaRepository
        self.historyRepository = historyRepository
        self.bookmarkRepository = bookmarkRepository
        self.scrobblingService = scrobblingService
        self.settings = settings
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let loaded = try await mangaRepository.pages(chapterID: chapter.id)
            pages = loaded
            currentIndex = min(initialPage, max(0, loaded.count - 1))
            applyKeepScreenOn(settings.keepScreenOn)
            await persistProgress()
            await scrobblingService.scrobble(manga: manga, chapterNumber: chapter.number)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleControls() { showsControls.toggle() }

    func onPageChanged(_ index: Int) {
        currentIndex = index
        Task { await persistProgress() }
    }

    func goNext() {
        guard currentIndex + 1 < pages.count else { return }
        currentIndex += 1
        Task { await persistProgress() }
    }

    func goPrevious() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        Task { await persistProgress() }
    }

    func openChapter(_ chapter: Chapter) async {
        self.chapter = chapter
        currentIndex = 0
        await load()
    }

    func adjacentChapter(delta: Int) -> Chapter? {
        guard let index = manga.chapters.firstIndex(where: { $0.id == chapter.id }) else { return nil }
        let next = index + delta
        guard manga.chapters.indices.contains(next) else { return nil }
        return manga.chapters[next]
    }

    func bookmarkCurrent() async {
        _ = await bookmarkRepository.add(
            mangaID: manga.id,
            chapterID: chapter.id,
            page: currentIndex,
            percent: progress
        )
    }

    func saveCurrentPageToPhotos() async -> Bool {
        guard pages.indices.contains(currentIndex) else { return false }
        let page = pages[currentIndex]
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }

        var image: UIImage?
        if page.url.hasPrefix("file://") || FileManager.default.fileExists(atPath: page.url) {
            let path = page.url.replacingOccurrences(of: "file://", with: "")
            image = UIImage(contentsOfFile: path)
        } else {
            image = await ImagePipeline.shared.load(urlString: page.url)
        }
        guard let image else { return false }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            return true
        } catch {
            AppLog.error("Save photo failed", error: error)
            return false
        }
    }

    private func persistProgress() async {
        guard !settings.incognitoMode else { return }
        await historyRepository.upsert(
            manga: manga,
            chapterID: chapter.id,
            page: currentIndex,
            percent: progress
        )
    }

    private func applyKeepScreenOn(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }

    func teardown() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
