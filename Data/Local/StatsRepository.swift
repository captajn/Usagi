import Foundation

actor StatsRepository {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL
    private var entries: [StatsEntry] = []
    private var loaded = false

    init(db: AppDatabase) {
        let root = db.storageRoot()
        self.fileURL = root.appendingPathComponent("stats.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadIfNeeded() {
        guard !loaded else { return }
        entries = (try? Data(contentsOf: fileURL)).flatMap { try? decoder.decode([StatsEntry].self, from: $0) } ?? []
        loaded = true
    }

    func upsert(_ entry: StatsEntry) {
        loadIfNeeded()
        if let i = entries.firstIndex(where: { $0.mangaId == entry.mangaId && Calendar.current.isDate($0.startedAt, inSameDayAs: entry.startedAt) }) {
            entries[i].duration += entry.duration
            entries[i].pages += entry.pages
        } else {
            entries.append(entry)
        }
        save()
    }

    func stats(for period: StatsPeriod, categories: [FavouriteCategory]? = nil, db: AppDatabase) -> [StatsRecord] {
        loadIfNeeded()
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
        return byManga.map { (id, val) in
            let manga = db.cachedManga(id: id)
            let pct = totalDuration > 0 ? val.duration / totalDuration * 100 : 0
            return StatsRecord(id: id, manga: manga, duration: val.duration, pages: val.pages, percentage: pct)
        }.sorted { $0.duration > $1.duration }
    }

    func totalPages(mangaId: Int64) -> Int {
        loadIfNeeded()
        return entries.filter { $0.mangaId == mangaId }.reduce(0) { $0 + $1.pages }
    }

    func timeline(mangaId: Int64, period: StatsPeriod) -> [(date: Date, pages: Int)] {
        loadIfNeeded()
        let from = period.dateFrom
        let grouped = Dictionary(grouping: entries.filter { $0.mangaId == mangaId && $0.startedAt >= from }) { entry in
            Calendar.current.startOfDay(for: entry.startedAt)
        }
        return grouped.map { (date: $0.key, pages: $0.value.reduce(0) { $0 + $1.pages }) }.sorted { $0.date < $1.date }
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
