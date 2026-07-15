import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        HistoryScreen(history: dependencies.historyRepository)
    }
}

private struct HistoryScreen: View {
    @StateObject private var viewModel: HistoryViewModel
    @State private var confirmClear = false

    init(history: HistoryRepository) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(history: history))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                LoadingView()
            } else if viewModel.entries.isEmpty {
                EmptyStateView(
                    systemImage: "clock",
                    title: "Chưa có lịch sử đọc",
                    message: "Truyện bạn mở sẽ xuất hiện ở đây."
                )
            } else {
                List {
                    ForEach(viewModel.entries) { entry in
                        NavigationLink(value: entry.manga.id) {
                            MangaRowView(
                                manga: entry.manga,
                                subtitle: viewModel.progressText(for: entry)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.remove(entry) }
                            } label: {
                                Label("Xoá", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Lịch sử")
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.entries.isEmpty {
                    Button("Xoá tất cả", role: .destructive) {
                        confirmClear = true
                    }
                }
            }
        }
        .confirmationDialog(
            "Xoá toàn bộ lịch sử?",
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button("Xoá", role: .destructive) {
                Task { await viewModel.clear() }
            }
            Button("Huỷ", role: .cancel) {}
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
