import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        SearchScreen(repository: dependencies.mangaRepository)
    }
}

private struct SearchScreen: View {
    @StateObject private var viewModel: SearchViewModel

    init(repository: MangaRepository) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(repository: repository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.results.isEmpty {
                LoadingView(message: "Đang tìm…")
            } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
                ErrorBanner(message: error) {
                    Task { await viewModel.search() }
                }
            } else if viewModel.didSearch && viewModel.results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "Không tìm thấy",
                    message: "Thử tên khác, tác giả, hoặc thể loại."
                )
            } else if !viewModel.didSearch {
                EmptyStateView(
                    systemImage: "text.page.badge.magnifyingglass",
                    title: "Tìm truyện",
                    message: "Tìm truyện từ các nguồn demo đang bật."
                )
            } else {
                List(viewModel.results) { manga in
                    NavigationLink(value: manga.id) {
                        MangaRowView(manga: manga)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Tìm kiếm")
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .searchable(
            text: Binding(
                get: { viewModel.query },
                set: { viewModel.onQueryChanged($0) }
            ),
            prompt: "Tên, tác giả, thể loại…"
        )
    }
}
