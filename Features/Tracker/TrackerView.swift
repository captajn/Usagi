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
                    title: String(localized: "No tracked manga"),
                    message: String(localized: "Track a title from its detail screen to see chapter updates here.")
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
                                        Text(String(localized: "\(entry.newChapters) new chapter(s)"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.orange)
                                    } else {
                                        Text(String(localized: "Up to date · \(entry.manga.chapterCount) ch"))
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
                            Button(String(localized: "Seen")) {
                                Task { await viewModel.markSeen(entry, deps: dependencies) }
                            }
                            .tint(.blue)
                            Button(role: .destructive) {
                                Task { await viewModel.untrack(entry, deps: dependencies) }
                            } label: {
                                Label(String(localized: "Remove"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(String(localized: "Updates"))
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
