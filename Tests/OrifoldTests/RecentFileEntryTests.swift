import XCTest
@testable import Orifold

final class RecentFileEntryTests: XCTestCase {
    func testCodableRoundTripPreservesAllFields() throws {
        let entry = RecentFileEntry(
            id: UUID(),
            bookmarkData: Data([0x01, 0x02, 0x03]),
            path: "/Users/test/Documents/Report.pdf",
            displayName: "Report",
            lastOpened: Date(timeIntervalSince1970: 1_700_000_000),
            pageCount: 24,
            lastPageOpened: 13,
            thumbnailCacheKey: "abc-123",
            thumbnailFailed: false
        )

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(RecentFileEntry.self, from: data)

        XCTAssertEqual(decoded, entry)
    }

    func testURLIsDerivedFromPath() {
        let entry = RecentFileEntry(
            id: UUID(),
            bookmarkData: nil,
            path: "/Users/test/Documents/Report.pdf",
            displayName: "Report",
            lastOpened: Date(),
            pageCount: nil,
            lastPageOpened: nil,
            thumbnailCacheKey: nil
        )

        XCTAssertEqual(entry.url.path, "/Users/test/Documents/Report.pdf")
    }
}
