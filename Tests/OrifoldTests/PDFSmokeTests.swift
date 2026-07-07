import AppKit
import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import Orifold

/// Minimal end-to-end sanity check for the PDF load -> export path, meant to
/// run fast and stay green as a PR-gate signal (see `swift test --filter
/// PDFSmokeTests`). Deeper format-specific coverage lives in
/// `QPDFServiceTests` / `SourceDocumentRoundTripTests`.
final class PDFSmokeTests: XCTestCase {
    func testLoadPageCountAndExportRoundTripProducesValidPDF() throws {
        let fixture = try makeTinyFixturePDF()

        let imported = try DocumentImportConverter.importedDocument(
            from: fixture,
            contentType: .pdf,
            filename: "smoke.pdf",
            baseURL: nil
        )
        XCTAssertEqual(imported.pdfDocument.pageCount, 1)

        let exported = try XCTUnwrap(imported.pdfDocument.dataRepresentation())
        XCTAssertFalse(exported.isEmpty)
        XCTAssertEqual(exported.prefix(5), Data("%PDF-".utf8))
        XCTAssertEqual(PDFDocument(data: exported)?.pageCount, 1)
    }

    private func makeTinyFixturePDF() throws -> Data {
        let view = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let pdf = PDFDocument()
        let page = try XCTUnwrap(PDFDocument(data: view.dataWithPDF(inside: view.bounds))?.page(at: 0))
        pdf.insert(page, at: 0)
        return try XCTUnwrap(pdf.dataRepresentation())
    }
}
