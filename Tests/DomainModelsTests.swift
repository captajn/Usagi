import XCTest
@testable import Usagi

final class DomainModelsTests: XCTestCase {
    func testReadingTimeEstimate() {
        let estimate = ReadingTimeEstimate.estimate(pages: 60, secondsPerPage: 8)
        XCTAssertEqual(estimate.minutes, 8)
    }

    func testDeepLinkManga() {
        let url = URL(string: "usagi://manga/42")!
        XCTAssertEqual(DeepLink.parse(url), .manga(id: 42))
    }

    func testDeepLinkSearch() {
        let url = URL(string: "usagi://search?q=usagi")!
        XCTAssertEqual(DeepLink.parse(url), .search(query: "usagi"))
    }

    func testChapterDisplayTitle() {
        let chapter = Chapter(
            id: 1,
            mangaID: 1,
            name: "Start",
            number: 1,
            volume: nil,
            branch: nil,
            uploadDate: nil,
            scanlator: nil,
            url: "",
            sourceID: "mock",
            pages: []
        )
        XCTAssertTrue(chapter.displayTitle.contains("1"))
    }

    func testMockCatalogNotEmpty() {
        XCTAssertFalse(MockData.manga.isEmpty)
        XCTAssertFalse(MockData.sources.isEmpty)
    }
}
