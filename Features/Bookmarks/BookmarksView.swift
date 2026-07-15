import SwiftUI

struct BookmarksView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var bookmarks: [Bookmark] = []
    @State private var mangaMap: [Int64: Manga] = [:]

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                EmptyStateView(
                    systemImage: "bookmark",
                    title: String(localized: "No bookmarks"),
                    message: String(localized: "Bookmark a page from the reader.")
                )
            } else {
                List {
                    ForEach(bookmarks) { bm in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mangaMap[bm.mangaID]?.title ?? "Manga #\(bm.mangaID)")
                                    .font(.headline)
                                Text(String(localized: "Chapter \(bm.chapterID) · page \(bm.page + 1)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(bm.createdAt, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text("\(Int(bm.percent * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    await dependencies.bookmarkRepository.remove(id: bm.id)
                                    await reload()
                                }
                            } label: {
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Bookmarks"))
        .task { await reload() }
    }

    private func reload() async {
        bookmarks = await dependencies.bookmarkRepository.all()
        var map: [Int64: Manga] = [:]
        for bm in bookmarks {
            if map[bm.mangaID] == nil {
                map[bm.mangaID] = await dependencies.database.cachedManga(id: bm.mangaID)
            }
        }
        mangaMap = map
    }
}
