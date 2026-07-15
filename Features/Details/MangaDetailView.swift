import SwiftUI

struct MangaDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let mangaID: Int64

    var body: some View {
        MangaDetailScreen(
            mangaID: mangaID,
            mangaRepository: dependencies.mangaRepository,
            library: dependencies.libraryRepository,
            history: dependencies.historyRepository,
            trackerRepository: dependencies.trackerRepository,
            downloadRepository: dependencies.downloadRepository,
            settings: dependencies.settings
        )
    }
}

private struct MangaDetailScreen: View {
    @StateObject private var viewModel: MangaDetailViewModel
    @State private var readerRoute: ReaderRoute?

    init(
        mangaID: Int64,
        mangaRepository: MangaRepository,
        library: LibraryRepository,
        history: HistoryRepository,
        trackerRepository: TrackerRepository,
        downloadRepository: DownloadRepository,
        settings: UserDefaultsSettingsStore
    ) {
        _viewModel = StateObject(
            wrappedValue: MangaDetailViewModel(
                mangaID: mangaID,
                mangaRepository: mangaRepository,
                library: library,
                history: history,
                trackerRepository: trackerRepository,
                downloadRepository: downloadRepository,
                settings: settings
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.manga == nil {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.manga == nil {
                ErrorBanner(message: error) {
                    Task { await viewModel.load() }
                }
            } else if let manga = viewModel.manga {
                detailBody(manga)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .fullScreenCover(item: $readerRoute) { route in
            ReaderView(manga: route.manga, chapter: route.chapter, initialPage: route.page)
        }
        .alert(
            String(localized: "Download"),
            isPresented: Binding(
                get: { viewModel.downloadMessage != nil },
                set: { if !$0 { viewModel.downloadMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.downloadMessage ?? "")
        }
    }

    @ViewBuilder
    private func detailBody(_ manga: Manga) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(manga)
                actions(manga)
                meta(manga)
                descriptionSection(manga)
                FlowTagsView(tags: manga.tags.map(\.title))
                chaptersSection(manga)
                if !viewModel.related.isEmpty {
                    relatedSection
                }
            }
            .padding()
        }
        .navigationTitle(manga.title)
    }

    private func header(_ manga: Manga) -> some View {
        HStack(alignment: .top, spacing: 16) {
            MangaCoverView(urlString: manga.largeCoverURL ?? manga.coverURL)
                .frame(width: 130)
                .shadow(radius: 6, y: 3)
                .accessibilityLabel(String(localized: "Cover for \(manga.title)"))

            VStack(alignment: .leading, spacing: 8) {
                Text(manga.title)
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                if !manga.altTitles.isEmpty {
                    Text(manga.altTitles.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(manga.authorsText).font(.subheadline)
                Label(manga.state.displayName, systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if manga.rating >= 0 {
                    Label(manga.ratingText, systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(String(localized: "\(manga.chapterCount) chapters"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func actions(_ manga: Manga) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if let chapter = viewModel.continueChapter() {
                    Button {
                        let page = viewModel.history?.chapterID == chapter.id
                            ? (viewModel.history?.page ?? 0) : 0
                        readerRoute = ReaderRoute(manga: manga, chapter: chapter, page: page)
                    } label: {
                        Label(
                            viewModel.history == nil
                                ? String(localized: "Read")
                                : String(localized: "Continue"),
                            systemImage: "book"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    Task { await viewModel.toggleFavourite() }
                } label: {
                    Image(systemName: viewModel.isFavourite ? "heart.fill" : "heart")
                        .frame(width: 44, height: 34)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isFavourite ? .pink : .accentColor)
                .accessibilityLabel(viewModel.isFavourite
                    ? String(localized: "Remove from library")
                    : String(localized: "Add to library"))

                Button {
                    Task { await viewModel.toggleTrack() }
                } label: {
                    Image(systemName: viewModel.isTracked ? "bell.fill" : "bell")
                        .frame(width: 44, height: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(viewModel.isTracked
                    ? String(localized: "Stop tracking")
                    : String(localized: "Track updates"))
            }
        }
    }

    private func meta(_ manga: Manga) -> some View {
        HStack(spacing: 16) {
            if let time = viewModel.readingTime {
                Label(time.displayText, systemImage: "clock")
            }
            Label(manga.contentRating.displayName, systemImage: "shield")
            Label(manga.sourceID, systemImage: "globe")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func descriptionSection(_ manga: Manga) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Synopsis")).font(.headline)
            Text(manga.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func chaptersSection(_ manga: Manga) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Chapters")).font(.headline)
            ForEach(manga.chapters) { chapter in
                HStack {
                    Button {
                        readerRoute = ReaderRoute(manga: manga, chapter: chapter, page: 0)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chapter.displayTitle).foregroundStyle(.primary)
                            if let scanlator = chapter.scanlator {
                                Text(scanlator).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        Task { await viewModel.download(chapter: chapter) }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .accessibilityLabel(String(localized: "Download \(chapter.displayTitle)"))
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Related")).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.related) { item in
                        NavigationLink(value: item.id) {
                            MangaCardView(manga: item).frame(width: 110)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ReaderRoute: Identifiable {
    let id = UUID()
    let manga: Manga
    let chapter: Chapter
    let page: Int
}

struct FlowTagsView: View {
    let tags: [String]

    var body: some View {
        FlexibleTagLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemFill), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FlexibleTagLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            width = max(width, x - spacing)
        }
        return (CGSize(width: width, height: y + rowHeight), frames)
    }
}
