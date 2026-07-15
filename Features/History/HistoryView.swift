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
                    title: String(localized: "No reading history"),
                    message: String(localized: "Titles you open will appear here.")
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
                                Label(String(localized: "Delete"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "History"))
        .navigationDestination(for: Int64.self) { id in
            MangaDetailView(mangaID: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.entries.isEmpty {
                    Button(String(localized: "Clear"), role: .destructive) {
                        confirmClear = true
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "Clear all history?"),
            isPresented: $confirmClear,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Clear"), role: .destructive) {
                Task { await viewModel.clear() }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }
}
