import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        LibraryScreen(library: dependencies.libraryRepository)
    }
}

private struct LibraryScreen: View {
    @StateObject private var viewModel: LibraryViewModel
    @State private var newCategoryName = ""
    @State private var showNewCategory = false

    init(library: LibraryRepository) {
        _viewModel = StateObject(wrappedValue: LibraryViewModel(library: library))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty && viewModel.categories.isEmpty {
                LoadingView()
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: String(localized: "Library is empty"),
                    message: String(localized: "Add manga from the detail screen with the heart button.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: UsagiTheme.gridColumns, spacing: UsagiTheme.gridSpacing) {
                        ForEach(viewModel.items) { manga in
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
        .navigationTitle(String(localized: "Library"))
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(String(localized: "All favourites")) {
                        Task { await viewModel.selectCategory(nil) }
                    }
                    Divider()
                    ForEach(viewModel.categories) { category in
                        Button {
                            Task { await viewModel.selectCategory(category.id) }
                        } label: {
                            if viewModel.selectedCategoryID == category.id {
                                Label(category.title, systemImage: "checkmark")
                            } else {
                                Text(category.title)
                            }
                        }
                    }
                    Divider()
                    Button(String(localized: "New category…")) {
                        showNewCategory = true
                    }
                } label: {
                    Image(systemName: "folder")
                }
            }
        }
        .alert(String(localized: "New category"), isPresented: $showNewCategory) {
            TextField(String(localized: "Name"), text: $newCategoryName)
            Button(String(localized: "Create")) {
                Task {
                    _ = await viewModel.createCategory(newCategoryName)
                    newCategoryName = ""
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
