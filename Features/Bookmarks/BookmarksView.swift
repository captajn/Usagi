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
                    title: "Chưa có đánh dấu",
                    message: "Đánh dấu trang từ trình đọc."
                )
            } else {
                List {
                    ForEach(bookmarks) { bm in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mangaMap[bm.mangaID]?.title ?? "Truyện #\(bm.mangaID)")
                                    .font(.headline)
                                Text("Chương \(bm.chapterID) · trang \(bm.page + 1)")
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
                                Label("Xoá", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Đánh dấu")
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
