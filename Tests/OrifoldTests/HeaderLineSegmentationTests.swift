import PDFKit
import XCTest
@testable import Orifold

/// WP-A: short standalone header lines and rule-less table cells must NOT merge into one
/// oversized block, while genuinely-wrapped paragraphs must still merge.
final class HeaderLineSegmentationTests: XCTestCase {
    private func analyze(_ data: Data) throws -> PDFTextPageAnalysis {
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        let p = try XCTUnwrap(pdf.page(at: 0))
        return PDFTextAnalysisEngine().analyze(data: data, pageIndex: 0, pageRefID: UUID(), fallbackPage: p)
    }

    private func block(_ analysis: PDFTextPageAnalysis, containing needle: String) -> EditableTextBlock? {
        analysis.blocks.first { $0.text.contains(needle) }
    }

    func testHeaderLinesStaySeparate() throws {
        let analysis = try analyze(EditingFixturePDFBuilder.monospacedHeaderPage())

        let title = try XCTUnwrap(block(analysis, containing: "SAMPLE PROJECT"))
        XCTAssertFalse(title.text.contains("Prepared for"), "title must not merge with the prepared-for line")
        XCTAssertFalse(title.text.contains("January"), "title must not merge with the date line")
        XCTAssertEqual(title.lines.count, 1, "title is a single line")

        let prepared = try XCTUnwrap(block(analysis, containing: "Demo Client"))
        XCTAssertFalse(prepared.text.contains("SAMPLE PROJECT"), "prepared-for must not include the title")
        XCTAssertFalse(prepared.text.contains("OVERVIEW"), "prepared-for must not merge with the overview header")

        let date = try XCTUnwrap(block(analysis, containing: "January 2026"))
        XCTAssertFalse(date.text.contains("SAMPLE PROJECT"), "date must not merge with the title")
        XCTAssertFalse(date.text.contains("Demo Client"), "date must not merge with the prepared-for line")

        let overview = try XCTUnwrap(block(analysis, containing: "OVERVIEW"))
        XCTAssertFalse(overview.text.contains("SAMPLE"), "OVERVIEW must not merge with the title")
        XCTAssertFalse(overview.text.contains("Demo Client"), "OVERVIEW must not merge with prepared-for")
    }

    func testWrappedControlParagraphStillMerges() throws {
        let analysis = try analyze(EditingFixturePDFBuilder.monospacedHeaderPage())
        let para = try XCTUnwrap(block(analysis, containing: "real wrapped"))
        XCTAssertTrue(para.text.contains("second line"), "a genuinely wrapped paragraph must still merge into one block")
        XCTAssertGreaterThanOrEqual(para.lines.count, 2, "the wrapped paragraph is multi-line")
    }

    func testRuleLessTableCellsStaySeparate() throws {
        let analysis = try analyze(EditingFixturePDFBuilder.monospacedHeaderPage())
        // The Phase column cells must not concatenate into one block.
        let discovery = try XCTUnwrap(block(analysis, containing: "Discovery"))
        XCTAssertFalse(discovery.text.contains("Build"), "table column cells must not merge (Discovery+Build)")
        XCTAssertFalse(discovery.text.contains("Review"), "table column cells must not merge (Discovery+Review)")
        let header = try XCTUnwrap(block(analysis, containing: "Phase"))
        XCTAssertFalse(header.text.contains("Discovery"), "column header must not merge with its first cell")
    }
}


