import Foundation

protocol DownloadRepository: Sendable {
    func items() async -> [DownloadItem]
    func enqueue(manga: Manga, chapter: Chapter) async -> DownloadItem
    func pause(id: UUID) async
    func resume(id: UUID) async
    func cancel(id: UUID) async
    func processQueue() async
}

actor DownloadManager: DownloadRepository {
    private let db: AppDatabase
    private let client: HTTPClient
    private var running = false

    init(db: AppDatabase = .shared, client: HTTPClient = HTTPClient()) {
        self.db = db
        self.client = client
    }

    func items() async -> [DownloadItem] {
        await db.allDownloads()
    }

    func enqueue(manga: Manga, chapter: Chapter) async -> DownloadItem {
        let item = DownloadItem(
            id: UUID(),
            mangaID: manga.id,
            mangaTitle: manga.title,
            chapterID: chapter.id,
            chapterTitle: chapter.displayTitle,
            coverURL: manga.coverURL,
            status: .queued,
            progress: 0,
            totalPages: chapter.pages.count,
            downloadedPages: 0,
            localDirectory: nil,
            errorMessage: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        try? await db.upsertDownload(item)
        try? await db.cacheManga(manga)
        Task { await processQueue() }
        return item
    }

    func pause(id: UUID) async {
        guard var item = await db.allDownloads().first(where: { $0.id == id }) else { return }
        item.status = .paused
        item.updatedAt = Date()
        try? await db.upsertDownload(item)
    }

    func resume(id: UUID) async {
        guard var item = await db.allDownloads().first(where: { $0.id == id }) else { return }
        item.status = .queued
        item.updatedAt = Date()
        try? await db.upsertDownload(item)
        await processQueue()
    }

    func cancel(id: UUID) async {
        if let item = await db.allDownloads().first(where: { $0.id == id }),
           let dir = item.localDirectory {
            try? FileManager.default.removeItem(atPath: dir)
        }
        try? await db.removeDownload(id: id)
    }

    func processQueue() async {
        guard !running else { return }
        running = true
        defer { running = false }

        while let item = await db.allDownloads().first(where: { $0.status == .queued || $0.status == .downloading }) {
            if item.status == .paused { break }
            await download(item)
        }
    }

    private func download(_ original: DownloadItem) async {
        var item = original
        item.status = .downloading
        item.updatedAt = Date()
        try? await db.upsertDownload(item)

        do {
            let root = try await db.downloadsDirectory()
            let dir = root
                .appendingPathComponent("\(item.mangaID)", isDirectory: true)
                .appendingPathComponent("\(item.chapterID)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // Resolve pages from mock catalog via remote pages if empty
            var pages = MockData.manga
                .first(where: { $0.id == item.mangaID })?
                .chapters.first(where: { $0.id == item.chapterID })?
                .pages ?? []

            if pages.isEmpty {
                // Placeholder single page
                pages = [Page(id: 0, index: 0, url: item.coverURL ?? "https://picsum.photos/seed/dl/800/1200")]
            }

            item.totalPages = pages.count
            var paths: [String] = []

            for (index, page) in pages.enumerated() {
                // Check pause
                if let latest = await db.allDownloads().first(where: { $0.id == item.id }), latest.status == .paused {
                    return
                }
                let dest = dir.appendingPathComponent(String(format: "%03d.jpg", index))
                if let url = URL(string: page.url) {
                    try await client.downloadFile(from: url, to: dest)
                }
                paths.append(dest.path)
                item.downloadedPages = index + 1
                item.progress = Float(index + 1) / Float(max(pages.count, 1))
                item.updatedAt = Date()
                try? await db.upsertDownload(item)
            }

            item.status = .completed
            item.progress = 1
            item.localDirectory = dir.path
            item.updatedAt = Date()
            try? await db.upsertDownload(item)

            let package = LocalChapterPackage(
                id: "\(item.mangaID)-\(item.chapterID)",
                mangaID: item.mangaID,
                chapterID: item.chapterID,
                mangaTitle: item.mangaTitle,
                chapterTitle: item.chapterTitle,
                pagePaths: paths,
                importedAt: Date(),
                source: .download
            )
            try? await db.upsertLocalChapter(package)
            AppLog.info("Downloaded chapter \(item.chapterTitle)")
        } catch {
            item.status = .failed
            item.errorMessage = error.localizedDescription
            item.updatedAt = Date()
            try? await db.upsertDownload(item)
            AppLog.error("Download failed", error: error)
        }
    }
}
