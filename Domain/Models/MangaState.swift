import Foundation
import SwiftUI

enum MangaPublicationState: String, Codable, CaseIterable, Identifiable, Sendable {
    case ongoing
    case finished
    case abandoned
    case paused
    case upcoming
    case restricted
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ongoing: return "Ongoing"
        case .finished: return "Finished"
        case .abandoned: return "Abandoned"
        case .paused: return "Paused"
        case .upcoming: return "Upcoming"
        case .restricted: return "Restricted"
        case .unknown: return "Unknown"
        }
    }
}

enum ContentRating: String, Codable, CaseIterable, Sendable {
    case safe
    case suggestive
    case adult
    case unknown

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .suggestive: return "Suggestive"
        case .adult: return "Adult"
        case .unknown: return "Unknown"
        }
    }
}

enum ReaderMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case pager
    case reversed
    case vertical
    case webtoon
    case doublePage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pager: return "Left to right"
        case .reversed: return "Right to left"
        case .vertical: return "Vertical"
        case .webtoon: return "Webtoon"
        case .doublePage: return "Double page"
        }
    }

    var systemImage: String {
        switch self {
        case .pager: return "book.pages"
        case .reversed: return "book.pages.fill"
        case .vertical: return "arrow.up.arrow.down"
        case .webtoon: return "rectangle.portrait.arrowtriangle.2.outward"
        case .doublePage: return "rectangle.split.2x1"
        }
    }
}

enum ColorSchemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
