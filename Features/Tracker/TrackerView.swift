import SwiftUI

struct TrackerView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = TrackerViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                LoadingView()
            } else if viewModel.entries.isEmpty {
                EmptyStateView(
                    systemImage: "bell.slash",
                    title: "Chưa theo dõi truyện nào",
                    message: "Theo dõi truyện từ màn hình chi tiết để xem cập nhật chương ở đây."
                )
            } else {
                List {
                    ForEach(viewModel.entries) { entry in
                        NavigationLink(value: entry.manga.id) {
                            HStack(spacing: 12) {
                                MangaCoverView(urlString: entry.manga.coverURL, cornerRadius: 8)
                                    .frame(width: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.manga.title)
                                        .font(.body.weight(.semibold))
                                        .lineLimit(2)
                                    if entry.hasUpdates {
                                        Text("\(entry.newChapters) chương mới")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.orange)
                                    } else {
                                        Text("Đã cập nhật · \(entry.manga.chapterCount) ch")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(entry.lastCheckedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Đã xem") {
                                Task { await viewModel.markSeen(entry, deps: dependencies) }
                            }
                            .tint(.blue)
                            Button(role: .destructive) {
                                Task { await viewModel.untrack(entry, deps: dependencies) }
                            } label: {
                                Label("Bỏ theo dõi", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Cập nhật")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh(deps: dependencies) }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await viewModel.load(deps: dependencies) }
        .refreshable { await viewModel.refresh(deps: dependencies) }
    }
}

@MainActor
final class TrackerViewModel: ObservableObject {
    @Published var entries: [TrackerEntry] = []
    @Published var isLoading = false
    @Published var isRefreshing = false

    func load(deps: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }
        entries = await deps.trackerRepository.entries()
    }

    func refresh(deps: AppDependencies) async {
        isRefreshing = true
        defer { isRefreshing = false }
        await deps.trackerRepository.refreshAll(using: deps.mangaRepository)
        entries = await deps.trackerRepository.entries()
    }

    func markSeen(_ entry: TrackerEntry, deps: AppDependencies) async {
        await deps.trackerRepository.markSeen(mangaID: entry.manga.id)
        await load(deps: deps)
    }

    func untrack(_ entry: TrackerEntry, deps: AppDependencies) async {
        await deps.trackerRepository.untrack(mangaID: entry.manga.id)
        await load(deps: deps)
    }
}
