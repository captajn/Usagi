import SwiftUI
import Charts

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
                    Chart(timeline, id: \.date) { item in
                        BarMark(
                            x: .value("Ngày", item.date, unit: .day),
                            y: .value("Trang", item.pages)
                        )
                        .foregroundStyle(UsagiTheme.accent)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
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
