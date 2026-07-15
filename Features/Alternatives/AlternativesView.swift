import SwiftUI

struct AlternativesView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    let manga: Manga

    var body: some View {
        AlternativesScreen(
            manga: manga,
            mangaRepository: dependencies.mangaRepository,
            database: dependencies.database
        )
    }
}

private struct AlternativesScreen: View {
    @StateObject private var viewModel: AlternativesViewModel
    @State private var showMigrateConfirm = false
    @State private var selectedTarget: Manga?

    let manga: Manga

    init(manga: Manga, mangaRepository: MangaRepository, database: AppDatabase) {
        self.manga = manga
        _viewModel = StateObject(
            wrappedValue: AlternativesViewModel(
                manga: manga,
                mangaRepository: mangaRepository,
                database: database
            )
        )
    }

    var body: some View {
        List {
            Section {
                HStack {
                    MangaCoverView(urlString: manga.largeCoverURL ?? manga.coverURL)
                        .frame(width: 50, height: 70)
                    VStack(alignment: .leading) {
                        Text(manga.title)
                            .font(.headline)
                        Text("\(manga.chapterCount) chương · \(manga.sourceID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Thay thế tìm thấy") {
                if viewModel.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else if viewModel.alternatives.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Không tìm thấy thay thế")
                            .foregroundStyle(.secondary)
                        if !viewModel.searchAllSources {
                            Button("Tìm tất cả nguồn") {
                                viewModel.searchAllSources = true
                                Task { await viewModel.search() }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    ForEach(viewModel.alternatives) { alt in
                        AlternativeRow(manga: alt, reference: manga) {
                            selectedTarget = alt
                            showMigrateConfirm = true
                        }
                    }

                    if !viewModel.searchAllSources {
                        Button("Tìm cả nguồn đã tắt") {
                            viewModel.searchAllSources = true
                            Task { await viewModel.search() }
                        }
                    }
                }
            }
        }
        .navigationTitle("Thay thế")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.search() }
        .confirmationDialog(
            "Chuyển sang \(selectedTarget?.title ?? "?")?",
            isPresented: $showMigrateConfirm,
            titleVisibility: .visible
        ) {
            Button("Chuyển") {
                if let target = selectedTarget {
                    Task { await viewModel.migrate(to: target) }
                }
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Thao tác này sẽ chuyển lịch sử đọc và yêu thích sang nguồn mới.")
        }
    }
}

struct AlternativeRow: View {
    let manga: Manga
    let reference: Manga
    let onMigrate: () -> Void

    var body: some View {
        HStack {
            MangaCoverView(urlString: manga.largeCoverURL ?? manga.coverURL)
                .frame(width: 50, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack {
                    Text(manga.sourceID)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())

                    let diff = manga.chapterCount - reference.chapterCount
                    if diff != 0 {
                        Text(diff > 0 ? "+\(diff)" : "\(diff)")
                            .font(.caption2)
                            .foregroundStyle(diff > 0 ? .green : .red)
                    }

                    Text("\(manga.chapterCount) ch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Chuyển") { onMigrate() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}
