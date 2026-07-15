import SwiftUI

/// Single-source manga listing — mirrors Android remotelist/ module.
/// Shows paginated manga results from one specific source with search + filter.
struct RemoteListView: View {
    let source: MangaSource
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel: RemoteListViewModel

    init(source: MangaSource) {
        self.source = source
        _viewModel = StateObject(wrappedValue: RemoteListViewModel(source: source))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.manga.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.manga.isEmpty {
                ErrorBanner(message: error) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.manga.isEmpty {
                EmptyStateView(
                    systemImage: "tray",
                    title: "Nguồn trống",
                    message: "Không có truyện nào từ nguồn này."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: UsagiTheme.gridColumns, spacing: UsagiTheme.gridSpacing) {
                        ForEach(viewModel.manga) { manga in
                            NavigationLink(value: manga.id) {
                                MangaCardView(manga: manga)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding()
                    }

                    if viewModel.hasMore {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task { await viewModel.loadMore() }
                            }
                    }
                }
                .refreshable { await viewModel.load() }
            }
        }
        .navigationTitle(source.title)
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .searchable(
            text: Binding(
                get: { viewModel.query },
                set: { viewModel.onQueryChanged($0) }
            ),
            prompt: "Tìm trong \(source.title)…"
        )
        .task { await viewModel.load() }
    }
}

@MainActor
final class RemoteListViewModel: ObservableObject {
    @Published var manga: [Manga] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var query = ""
    @Published var hasMore = true

    let source: MangaSource
    private let repository: MangaRepository
    private var offset = 0
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    init(source: MangaSource) {
        self.source = source
        self.repository = MangaDexRepository()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        offset = 0
        defer { isLoading = false }
        do {
            let results: [Manga]
            if query.isEmpty {
                results = try await repository.popular(sourceID: source.id)
            } else {
                results = try await repository.search(query: query, sourceID: source.id)
            }
            manga = Array(results.prefix(pageSize))
            hasMore = results.count >= pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, !query.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let results = try await repository.search(query: query, sourceID: source.id)
            let newItems = results.dropFirst(offset + pageSize).prefix(pageSize)
            manga.append(contentsOf: newItems)
            offset += newItems.count
            hasMore = newItems.count >= pageSize
        } catch {
            // Silently fail on pagination — user can retry
        }
    }

    func onQueryChanged(_ newQuery: String) {
        query = newQuery
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await load()
        }
    }
}
