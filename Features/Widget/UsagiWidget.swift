import WidgetKit
import SwiftUI

/// iOS WidgetKit widgets — mirrors Android widget/ module.
/// Two types: RecentWidget (recently read) and ShelfWidget (favourites).

// MARK: - Timeline Provider

struct UsagiTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), manga: [], type: .recent)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date(), manga: [], type: .recent))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        Task {
            let db = AppDatabase.shared
            try? await db.prepare()
            let history = db.historyEntries()
            let entries = history.prefix(5).map { $0.manga }
            let entry = SimpleEntry(date: Date(), manga: entries, type: .recent)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let manga: [Manga]
    let type: WidgetType
}

enum WidgetType { case recent, shelf }

// MARK: - Recent Widget

struct RecentWidget: Widget {
    let kind: String = "RecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsagiTimelineProvider()) { entry in
            RecentWidgetView(entry: entry)
        }
        .configurationDisplayName("Truyện gần đây")
        .description("Hiển thị truyện bạn đọc gần đây.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct RecentWidgetView: View {
    let entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.manga.isEmpty {
            VStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Chưa có lịch sử")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            switch family {
            case .systemMedium:
                mediumLayout
            default:
                largeLayout
            }
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 8) {
            ForEach(entry.manga.prefix(4)) { manga in
                VStack(spacing: 4) {
                    AsyncImage(url: URL(string: manga.coverURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                        }
                    }
                    .frame(width: 60, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(manga.title)
                        .font(.caption2)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Truyện gần đây")
                .font(.headline)
            ForEach(entry.manga.prefix(5)) { manga in
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: manga.coverURL ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                        }
                    }
                    .frame(width: 30, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(manga.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
        .padding()
    }
}

// MARK: - Shelf Widget

struct ShelfWidget: Widget {
    let kind: String = "ShelfWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsagiTimelineProvider()) { entry in
            ShelfWidgetView(entry: entry)
        }
        .configurationDisplayName("Truyện yêu thích")
        .description("Hiển thị ảnh bìa truyện yêu thích.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct ShelfWidgetView: View {
    let entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if entry.manga.isEmpty {
            VStack {
                Image(systemName: "heart.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Chưa có yêu thích")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            switch family {
            case .systemMedium:
                gridLayout(columns: 3)
            default:
                gridLayout(columns: 4)
            }
        }
    }

    private func gridLayout(columns: Int) -> some View {
        let items = Array(entry.manga.prefix(columns * 2))
        return VStack(alignment: .leading, spacing: 8) {
            Text("Yêu thích")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
                ForEach(items) { manga in
                    VStack(spacing: 4) {
                        AsyncImage(url: URL(string: manga.coverURL ?? "")) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                            }
                        }
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(manga.title)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Widget Bundle

@main
struct UsagiWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentWidget()
        ShelfWidget()
    }
}
