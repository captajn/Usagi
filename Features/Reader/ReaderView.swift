import SwiftUI
import Photos

struct ReaderView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let manga: Manga
    let chapter: Chapter
    let initialPage: Int

    var body: some View {
        ReaderScreen(
            manga: manga,
            chapter: chapter,
            initialPage: initialPage,
            mangaRepository: dependencies.mangaRepository,
            historyRepository: dependencies.historyRepository,
            bookmarkRepository: dependencies.bookmarkRepository,
            scrobblingService: dependencies.scrobblingService,
            settings: dependencies.settings
        )
    }
}

private struct ReaderScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ReaderViewModel
    @ObservedObject private var settings: UserDefaultsSettingsStore
    @State private var showSettings = false
    @State private var toast: String?
    @State private var autoScrollTask: Task<Void, Never>?

    init(
        manga: Manga,
        chapter: Chapter,
        initialPage: Int,
        mangaRepository: MangaRepository,
        historyRepository: HistoryRepository,
        bookmarkRepository: BookmarkRepository,
        scrobblingService: ScrobblingService,
        settings: UserDefaultsSettingsStore
    ) {
        self.settings = settings
        _viewModel = StateObject(
            wrappedValue: ReaderViewModel(
                manga: manga,
                chapter: chapter,
                initialPage: initialPage,
                mangaRepository: mangaRepository,
                historyRepository: historyRepository,
                bookmarkRepository: bookmarkRepository,
                scrobblingService: scrobblingService,
                settings: settings
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isLoading && viewModel.pages.isEmpty {
                ProgressView().tint(.white)
            } else if let error = viewModel.errorMessage, viewModel.pages.isEmpty {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.white)
                    Button(String(localized: "Close")) { dismiss() }
                }
            } else {
                readerContent
                    .brightness((settings.readerBrightness - 1) * 0.35)
                    .colorMultiply(settings.colorFilter.isEnabled && settings.colorFilter.grayscale ? .gray : .white)
                    .saturation(settings.colorFilter.isEnabled && settings.colorFilter.grayscale ? 0 : 1)
                    .contrast(settings.colorFilter.isEnabled ? settings.colorFilter.contrast : 1)
                    .colorInvert(settings.colorFilter.isEnabled && settings.colorFilter.inversion)

                if viewModel.showsControls {
                    controlsOverlay
                }

                if let toast {
                    Text(toast)
                        .font(.caption.weight(.semibold))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity)
                }
            }
        }
        .statusBarHidden(!viewModel.showsControls)
        .task {
            await viewModel.load()
            restartAutoScroll()
        }
        .onDisappear {
            viewModel.teardown()
            autoScrollTask?.cancel()
        }
        .onChange(of: settings.autoScrollEnabled) { _, _ in restartAutoScroll() }
        .onChange(of: settings.autoScrollSeconds) { _, _ in restartAutoScroll() }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ReaderSettingsSheet(settings: settings)
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        switch viewModel.readerMode {
        case .webtoon, .vertical:
            webtoonReader
        case .reversed:
            pagedReader(leftToRight: false)
        case .pager, .doublePage:
            pagedReader(leftToRight: true)
        }
    }

    private func pagedReader(leftToRight: Bool) -> some View {
        TabView(selection: Binding(
            get: { viewModel.currentIndex },
            set: { viewModel.onPageChanged($0) }
        )) {
            ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                ZoomablePageView(urlString: page.url) {
                    // handled via zone
                } onDoubleTapZone: { point, size in
                    handleTap(at: point, in: size)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .environment(\.layoutDirection, leftToRight ? .leftToRight : .rightToLeft)
    }

    private var webtoonReader: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    ReaderPageView(urlString: page.url)
                        .onAppear { viewModel.onPageChanged(index) }
                        .onTapGesture { location in
                            // approximate full width zones
                            handleTap(at: location, in: UIScreen.main.bounds.size)
                        }
                }
            }
        }
    }

    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(String(localized: "Close reader"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.manga.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(viewModel.chapter.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(viewModel.pageLabel)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .accessibilityLabel(String(localized: "Page \(viewModel.currentIndex + 1) of \(viewModel.pages.count)"))
            }
            .padding()
            .background(.ultraThinMaterial)

            Spacer()

            VStack(spacing: 12) {
                ProgressView(value: Double(viewModel.progress))
                    .tint(.white)

                HStack(spacing: 16) {
                    Button {
                        if viewModel.currentIndex == 0, let prev = viewModel.adjacentChapter(delta: -1) {
                            Task { await viewModel.openChapter(prev) }
                        } else {
                            viewModel.goPrevious()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel(String(localized: "Previous page"))

                    Button {
                        Task {
                            await viewModel.bookmarkCurrent()
                            showToast(String(localized: "Bookmark saved"))
                        }
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .accessibilityLabel(String(localized: "Bookmark page"))

                    Button {
                        Task {
                            let ok = await viewModel.saveCurrentPageToPhotos()
                            showToast(ok ? String(localized: "Saved to Photos") : String(localized: "Save failed"))
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel(String(localized: "Save page"))

                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(String(localized: "Reader settings"))

                    Button {
                        if viewModel.currentIndex >= viewModel.pages.count - 1,
                           let next = viewModel.adjacentChapter(delta: 1) {
                            Task { await viewModel.openChapter(next) }
                        } else {
                            viewModel.goNext()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel(String(localized: "Next page"))
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .foregroundStyle(.primary)
    }

    private func handleTap(at point: CGPoint, in size: CGSize) {
        let x = point.x / max(size.width, 1)
        let action: TapZoneAction
        if x < 0.33 {
            action = settings.tapGrid.left
        } else if x > 0.66 {
            action = settings.tapGrid.right
        } else {
            action = settings.tapGrid.center
        }
        switch action {
        case .none: break
        case .prevPage: viewModel.goPrevious()
        case .nextPage: viewModel.goNext()
        case .toggleUI: viewModel.toggleControls()
        }
    }

    private func restartAutoScroll() {
        autoScrollTask?.cancel()
        guard settings.autoScrollEnabled else { return }
        autoScrollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(settings.autoScrollSeconds * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if viewModel.currentIndex < viewModel.pages.count - 1 {
                        viewModel.goNext()
                    }
                }
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { withAnimation { toast = nil } }
        }
    }
}

struct ReaderPageView: View {
    let urlString: String

    var body: some View {
        GeometryReader { geo in
            if urlString.hasPrefix("file://") || (!urlString.hasPrefix("http") && FileManager.default.fileExists(atPath: urlString)) {
                localImage(urlString)
                    .frame(width: geo.size.width)
            } else if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack { Color.black; ProgressView().tint(.white) }
                    case .success(let image):
                        image.resizable().scaledToFit().frame(width: geo.size.width)
                    case .failure:
                        ZStack {
                            Color.black
                            Text(String(localized: "Failed to load page")).foregroundStyle(.white.opacity(0.7))
                        }
                    @unknown default:
                        Color.black
                    }
                }
            } else {
                Color.black
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private func localImage(_ path: String) -> some View {
        let filePath = path.replacingOccurrences(of: "file://", with: "")
        if let ui = UIImage(contentsOfFile: filePath) {
            Image(uiImage: ui).resizable().scaledToFit()
        } else {
            Color.black
        }
    }
}

struct ReaderSettingsSheet: View {
    @ObservedObject var settings: UserDefaultsSettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(String(localized: "Mode")) {
                Picker(String(localized: "Reading mode"), selection: $settings.readerMode) {
                    ForEach(ReaderMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.systemImage).tag(mode)
                    }
                }
            }
            Section(String(localized: "Display")) {
                Toggle(String(localized: "Keep screen on"), isOn: $settings.keepScreenOn)
                HStack {
                    Text(String(localized: "Brightness"))
                    Slider(value: $settings.readerBrightness, in: 0.4...1.2)
                }
            }
            Section(String(localized: "Auto-scroll")) {
                Toggle(String(localized: "Enabled"), isOn: $settings.autoScrollEnabled)
                HStack {
                    Text(String(localized: "Interval"))
                    Slider(value: $settings.autoScrollSeconds, in: 2...15, step: 1)
                    Text("\(Int(settings.autoScrollSeconds))s")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            Section(String(localized: "Color filter")) {
                Toggle(String(localized: "Enabled"), isOn: $settings.colorFilter.isEnabled)
                Toggle(String(localized: "Grayscale"), isOn: $settings.colorFilter.grayscale)
                Toggle(String(localized: "Invert"), isOn: $settings.colorFilter.inversion)
                HStack {
                    Text(String(localized: "Contrast"))
                    Slider(value: $settings.colorFilter.contrast, in: 0.5...1.5)
                }
            }
            Section(String(localized: "Tap zones")) {
                Picker(String(localized: "Left"), selection: $settings.tapGrid.left) {
                    ForEach(TapZoneAction.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker(String(localized: "Center"), selection: $settings.tapGrid.center) {
                    ForEach(TapZoneAction.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Picker(String(localized: "Right"), selection: $settings.tapGrid.right) {
                    ForEach(TapZoneAction.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
        }
        .navigationTitle(String(localized: "Reader settings"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Done")) { dismiss() }
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func colorInvert(_ enabled: Bool) -> some View {
        if enabled { self.colorInvert() } else { self }
    }
}
