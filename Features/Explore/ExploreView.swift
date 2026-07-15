import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModelHolder = ExploreViewModelHolder()

    var body: some View {
        content
            .navigationTitle("Khám phá")
            .navigationDestination(for: Int64.self) { id in
                MangaDetailView(mangaID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Tìm kiếm")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Tất cả nguồn") {
                            Task { await viewModel?.selectSource(nil) }
                        }
                        Divider()
                        ForEach(viewModel?.sources ?? []) { source in
                            Button {
                                Task { await viewModel?.selectSource(source.id) }
                            } label: {
                                if viewModel?.selectedSourceID == source.id {
                                    Label(source.title, systemImage: "checkmark")
                                } else {
                                    Text(source.title)
                                }
                            }
                            .disabled(!source.isEnabled)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Lọc nguồn")
                }
            }
            .task {
                viewModelHolder.bind(repository: dependencies.mangaRepository)
                await viewModelHolder.viewModel?.load()
                if let pending = dependencies.navigation.pendingMangaID {
                    dependencies.navigation.pendingMangaID = nil
                    _ = pending
                }
            }
            .refreshable { await viewModel?.load() }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            Group {
                if viewModel.isLoading && viewModel.popular.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.popular.isEmpty {
                    ErrorBanner(message: error) {
                        Task { await viewModel.load() }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let sourceID = viewModel.selectedSourceID,
                               let source = viewModel.sources.first(where: { $0.id == sourceID }) {
                                Text("Nguồn: \(source.title)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            }

                            shelf(title: "Phổ biến", items: viewModel.popular)
                            shelf(title: "Mới nhất", items: viewModel.latest)

                            NavigationLink {
                                SuggestionsView()
                            } label: {
                                Label("Xem gợi ý", systemImage: "sparkles")
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        } else {
            LoadingView()
        }
    }

    private var viewModel: ExploreViewModel? { viewModelHolder.viewModel }

    private func shelf(title: String, items: [Manga]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { manga in
                        NavigationLink(value: manga.id) {
                            MangaCardView(manga: manga)
                                .frame(width: 120)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

@MainActor
private final class ExploreViewModelHolder: ObservableObject {
    @Published var viewModel: ExploreViewModel?

    func bind(repository: MangaRepository) {
        guard viewModel == nil else { return }
        viewModel = ExploreViewModel(repository: repository)
    }
}
