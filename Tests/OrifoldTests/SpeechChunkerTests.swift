import XCTest
@testable import Orifold

/// Feature C1: the pure sentence chunker that read-aloud speaks one utterance at a
/// time. Ranges are UTF-16 `NSRange`s so they map cleanly onto what
/// `PDFPage.selection(for:)` expects for follow-along highlighting.
final class SpeechChunkerTests: XCTestCase {

    func testTwoSentencesProduceTwoChunksWithReconstructableRanges() {
        let text = "Hello world. Goodbye moon."
        let chunks = SpeechChunker.chunks(forPageText: text, pageIndex: 3)

        XCTAssertEqual(chunks.count, 2)
        let ns = text as NSString
        for chunk in chunks {
            XCTAssertEqual(chunk.pageIndex, 3)
            // The stored text must be exactly the substring the NSRange points at, so the
            // highlight bridge can round-trip range → substring without drift.
            XCTAssertEqual(ns.substring(with: chunk.rangeInPage), chunk.text)
        }
        XCTAssertTrue(chunks[0].text.contains("Hello world"))
        XCTAssertTrue(chunks[1].text.contains("Goodbye moon"))
    }

    func testEmptyTextProducesNoChunks() {
        XCTAssertEqual(SpeechChunker.chunks(forPageText: "", pageIndex: 0), [])
    }

    func testWhitespaceOnlyTextProducesNoChunks() {
        XCTAssertEqual(SpeechChunker.chunks(forPageText: "   \n\t  ", pageIndex: 0), [])
    }

    /// CJK text has no ASCII whitespace between sentences; ranges must still stay
    /// UTF-16-consistent so `(text as NSString).substring(with:)` reconstructs each chunk.
    func testCJKRangesStayUTF16Consistent() {
        let text = "こんにちは。ありがとう。"
        let chunks = SpeechChunker.chunks(forPageText: text, pageIndex: 0)

        XCTAssertEqual(chunks.count, 2)
        let ns = text as NSString
        XCTAssertEqual(ns.substring(with: chunks[0].rangeInPage), chunks[0].text)
        XCTAssertEqual(ns.substring(with: chunks[1].rangeInPage), chunks[1].text)
    }
}
