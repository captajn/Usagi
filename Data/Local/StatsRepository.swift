import Foundation

@MainActor
final class StatsRepository {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let db: AppDatabase
    private var fileURL: URL?
    private var entries: [StatsEntry] = []
    private var loaded = false

    init(db: AppDatabase) {
        self.db = db
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    private func ensureURL() async {
        guard fileURL == nil else { return }
        let root = await db.storageRoot()
        fileURL = root.appendingPathComponent("stats.json")
    }

    private func loadIfNeeded() async {
        guard !loaded else { return }
        await ensureURL()
        guard let url = fileURL else { return }
        entries = (try? Data(contentsOf: url)).flatMap { try? decoder.decode([StatsEntry].self, from: $0) } ?? []
        loaded = true
    }

    func upsert(_ entry: StatsEntry) async {
        await loadIfNeeded()
        if let i = entries.firstIndex(where: { $0.mangaId == entry.mangaId && Calendar.current.isDate($0.startedAt, inSameDayAs: entry.startedAt) }) {
            entries[i].duration += entry.duration
            entries[i].pages += entry.pages
        } else {
            entries.append(entry)
        }
        save()
    }

    func stats(for period: StatsPeriod, categories: [FavouriteCategory]? = nil) async -> [StatsRecord] {
        await loadIfNeeded()
        let from = period.dateFrom
        var filtered = entries.filter { $0.startedAt >= from }
        if let cats = categories {
            let allowed = Set(cats.flatMap { $0.mangaIDs })
            if !allowed.isEmpty { filtered = filtered.filter { allowed.contains($0.mangaId) } }
        }
        var byManga: [Int64: (duration: TimeInterval, pages: Int)] = [:]
        for e in filtered {
            var acc = byManga[e.mangaId] ?? (0, 0)
            acc.duration += e.duration
            acc.pages += e.pages
            byManga[e.mangaId] = acc
        }
        let totalDuration = byManga.values.reduce(0) { $0 + $1.duration }
        var results: [StatsRecord] = []
        for (id, val) in byManga {
            let manga = await db.cachedManga(id: id)
            let pct = totalDuration > 0 ? val.duration / totalDuration * 100 : 0
            results.append(StatsRecord(id: id, manga: manga, duration: val.duration, pages: val.pages, percentage: pct))
        }
        return results.sorted { $0.duration > $1.duration }
    }

    func totalPages(mangaId: Int64) async -> Int {
        await loadIfNeeded()
        return entries.filter { $0.mangaId == mangaId }.reduce(0) { $0 + $1.pages }
    }

    func timeline(mangaId: Int64, period: StatsPeriod) async -> [(date: Date, pages: Int)] {
        await loadIfNeeded()
        let from = period.dateFrom
        let grouped = Dictionary(grouping: entries.filter { $0.mangaId == mangaId && $0.startedAt >= from }) { entry in
            Calendar.current.startOfDay(for: entry.startedAt)
        }
        return grouped.map { (date: $0.key, pages: $0.value.reduce(0) { $0 + $1.pages }) }.sorted { $0.date < $1.date }
    }

    func clear() async {
        await loadIfNeeded()
        entries.removeAll()
        save()
    }

    private func save() {
        guard let url = fileURL, let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
