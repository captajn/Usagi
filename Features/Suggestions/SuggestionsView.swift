import SwiftUI

struct SuggestionsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var items: [Manga] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if items.isEmpty {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "Chưa có gợi ý",
                    message: "Đọc thêm truyện để chúng tôi gợi ý truyện tương tự."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: UsagiTheme.gridColumns, spacing: UsagiTheme.gridSpacing) {
                        ForEach(items) { manga in
                            NavigationLink(value: manga.id) {
                                MangaCardView(manga: manga)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Gợi ý")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let history = await dependencies.historyRepository.entries()
        let favTags = Set(history.flatMap { $0.manga.tags.map(\.key) })
        do {
            let popular = try await dependencies.mangaRepository.popular(sourceID: nil)
            if favTags.isEmpty {
                items = Array(popular.prefix(8))
            } else {
                items = popular
                    .filter { m in m.tags.contains { favTags.contains($0.key) } }
                    .filter { m in !history.contains(where: { $0.manga.id == m.id }) }
                if items.count < 4 {
                    items = Array(popular.prefix(8))
                }
            }
        } catch {
            items = []
        }
    }
}
