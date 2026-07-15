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
                    title: "Thư viện trống",
                    message: "Thêm truyện từ màn hình chi tiết bằng nút trái tim."
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
        .navigationTitle("Thư viện")
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Tất cả yêu thích") {
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
                    Button("Danh mục mới…") {
                        showNewCategory = true
                    }
                } label: {
                    Image(systemName: "folder")
                }
            }
        }
        .alert("Danh mục mới", isPresented: $showNewCategory) {
            TextField("Tên", text: $newCategoryName)
            Button("Tạo") {
                Task {
                    _ = await viewModel.createCategory(newCategoryName)
                    newCategoryName = ""
                }
            }
            Button("Huỷ", role: .cancel) {}
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
