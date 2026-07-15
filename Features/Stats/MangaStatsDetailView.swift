import SwiftUI

struct MangaStatsDetailView: View {
    let manga: Manga
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var totalPages = 0
    @State private var timeline: [(date: Date, pages: Int)] = []

    var body: some View {
        List {
            Section {
                HStack {
                    MangaCoverView(urlString: manga.coverURL)
                        .frame(width: 60, height: 60)
                        .clipped()
                    VStack(alignment: .leading) {
                        Text(manga.title)
                            .font(.headline)
                        Text("\(totalPages) trang đã đọc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !timeline.isEmpty {
                Section("Trang mỗi ngày") {
                    ForEach(timeline, id: \.date) { item in
                        HStack {
                            Text(item.date, style: .date)
                                .font(.caption)
                            Spacer()
                            Text("\(item.pages) trang")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .background(
                            GeometryReader { geo in
                                let maxPages = Double(timeline.map(\.pages).max() ?? 1)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(UsagiTheme.accent.opacity(0.15))
                                    .frame(width: geo.size.width * (Double(item.pages) / maxPages))
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Thống kê đọc")
        .task {
            totalPages = await dependencies.statsRepository.totalPages(mangaId: manga.id)
            timeline = await dependencies.statsRepository.timeline(mangaId: manga.id, period: .all)
        }
    }
}
