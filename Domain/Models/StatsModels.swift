import Foundation

struct StatsRecord: Identifiable, Hashable, Codable, Sendable {
    let id: Int64
    var manga: Manga?
    var duration: TimeInterval
    var pages: Int
    var percentage: Double

    var displayTime: String {
        let h = Int(duration) / 3600
        let m = Int(duration) % 3600 / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

enum StatsPeriod: String, CaseIterable, Identifiable, Codable {
    case day, week, month, months3, all
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .day: return "Last 24h"
        case .week: return "Last 7 days"
        case .month: return "Last 30 days"
        case .months3: return "Last 90 days"
        case .all: return "All time"
        }
    }
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .months3: return 90
        case .all: return 36500
        }
    }
    var dateFrom: Date { Calendar.current.date(byAdding: .day, value: -days, to: Date())! }
}

struct StatsEntry: Identifiable, Hashable, Codable, Sendable {
    var id: String { "\(mangaId)-\(startedAt.timeIntervalSince1970)" }
    var mangaId: Int64
    var startedAt: Date
    var duration: TimeInterval
    var pages: Int
}
