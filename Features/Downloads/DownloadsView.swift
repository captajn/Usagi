import SwiftUI
import UniformTypeIdentifiers

struct DownloadsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = DownloadsViewModel()
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        Group {
            if viewModel.items.isEmpty && viewModel.localPackages.isEmpty {
                EmptyStateView(
                    systemImage: "arrow.down.circle",
                    title: String(localized: "No downloads"),
                    message: String(localized: "Download chapters from manga details, or import a CBZ/ZIP.")
                )
            } else {
                List {
                    if !viewModel.items.isEmpty {
                        Section(String(localized: "Queue")) {
                            ForEach(viewModel.items) { item in
                                DownloadRow(item: item) {
                                    Task { await viewModel.pauseOrResume(item, deps: dependencies) }
                                } onCancel: {
                                    Task { await viewModel.cancel(item, deps: dependencies) }
                                }
                            }
                        }
                    }
                    if !viewModel.localPackages.isEmpty {
                        Section(String(localized: "Offline / Imported")) {
                            ForEach(viewModel.localPackages) { pack in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pack.mangaTitle).font(.headline)
                                    Text(pack.chapterTitle).font(.subheadline).foregroundStyle(.secondary)
                                    Text("\(pack.pagePaths.count) pages · \(pack.source.rawValue)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Downloads"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    importing = true
                } label: {
                    Label(String(localized: "Import CBZ"), systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.zip, UTType(filenameExtension: "cbz") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            Task {
                do {
                    let url = try result.get().first
                    guard let url else { return }
                    _ = try await dependencies.cbzImporter.importCBZ(from: url)
                    await viewModel.load(deps: dependencies)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .task { await viewModel.load(deps: dependencies) }
        .refreshable { await viewModel.load(deps: dependencies) }
    }
}

private struct DownloadRow: View {
    let item: DownloadItem
    var onPauseResume: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.mangaTitle).font(.headline)
                    Text(item.chapterTitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(item.status.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(item.progress))
            HStack {
                Text("\(item.downloadedPages)/\(item.totalPages) · \(item.percentText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if item.status == .downloading || item.status == .queued {
                    Button(String(localized: "Pause"), action: onPauseResume)
                } else if item.status == .paused || item.status == .failed {
                    Button(String(localized: "Resume"), action: onPauseResume)
                }
                if item.status != .completed {
                    Button(String(localized: "Cancel"), role: .destructive, action: onCancel)
                }
            }
            .font(.caption)
            if let err = item.errorMessage {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class DownloadsViewModel: ObservableObject {
    @Published var items: [DownloadItem] = []
    @Published var localPackages: [LocalChapterPackage] = []

    func load(deps: AppDependencies) async {
        items = await deps.downloadRepository.items()
        localPackages = await deps.database.allLocalChapters()
    }

    func pauseOrResume(_ item: DownloadItem, deps: AppDependencies) async {
        if item.status == .paused || item.status == .failed {
            await deps.downloadRepository.resume(id: item.id)
        } else {
            await deps.downloadRepository.pause(id: item.id)
        }
        await load(deps: deps)
    }

    func cancel(_ item: DownloadItem, deps: AppDependencies) async {
        await deps.downloadRepository.cancel(id: item.id)
        await load(deps: deps)
    }
}
