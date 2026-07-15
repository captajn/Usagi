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
                LoadingView(message: "Searching…")
            } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
                ErrorBanner(message: error) {
                    Task { await viewModel.search() }
                }
            } else if viewModel.didSearch && viewModel.results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No results",
                    message: "Try another title, author, or tag."
                )
            } else if !viewModel.didSearch {
                EmptyStateView(
                    systemImage: "text.page.badge.magnifyingglass",
                    title: "Search manga",
                    message: "Find titles from enabled demo sources."
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
        .navigationTitle("Search")
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .searchable(
            text: Binding(
                get: { viewModel.query },
                set: { viewModel.onQueryChanged($0) }
            ),
            prompt: "Title, author, tag…"
        )
    }
}
