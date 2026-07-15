import Foundation

protocol BookmarkRepository: Sendable {
    func all() async -> [Bookmark]
    func add(mangaID: Int64, chapterID: Int64, page: Int, percent: Float) async -> Bookmark
    func remove(id: UUID) async
}

actor PersistentBookmarkRepository: BookmarkRepository {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    func all() async -> [Bookmark] {
        await db.allBookmarks()
    }

    func add(mangaID: Int64, chapterID: Int64, page: Int, percent: Float) async -> Bookmark {
        let bookmark = Bookmark(
            id: UUID(),
            mangaID: mangaID,
            chapterID: chapterID,
            page: page,
            createdAt: Date(),
            percent: percent
        )
        try? await db.addBookmark(bookmark)
        return bookmark
    }

    func remove(id: UUID) async {
        try? await db.removeBookmark(id: id)
    }
}
