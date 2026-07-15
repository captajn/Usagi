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
        case .ongoing: return "Đang cập nhật"
        case .finished: return "Hoàn thành"
        case .abandoned: return "Bỏ ngỏ"
        case .paused: return "Tạm ngưng"
        case .upcoming: return "Sắp ra mắt"
        case .restricted: return "Hạn chế"
        case .unknown: return "Không rõ"
        }
    }
}

enum ContentRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case safe
    case suggestive
    case adult
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .safe: return "An toàn"
        case .suggestive: return "Gợi ý"
        case .adult: return "Người lớn"
        case .unknown: return "Không rõ"
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
        case .pager: return "Trái sang phải"
        case .reversed: return "Phải sang trái"
        case .vertical: return "Dọc"
        case .webtoon: return "Webtoon"
        case .doublePage: return "Trang đôi"
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
        case .system: return "Hệ thống"
        case .light: return "Sáng"
        case .dark: return "Tối"
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
