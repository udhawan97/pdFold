import PDFKit
import UniformTypeIdentifiers
import XCTest
@testable import Orifold

/// Covers the bundled CC0 sample/onboarding document (Feature D).
final class SampleDocumentTests: XCTestCase {
    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/OrifoldTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // repo root
    }

    /// Regenerates `Orifold/Resources/SampleDocument.pdf` from the committed markdown
    /// source, driving it through the *exact* markdown→PDF path a real import uses
    /// (`DocumentImportConverter.importedDocument`), so the asset looks like something
    /// Orifold produced. Env-gated: it writes into the source tree, so it only runs when
    /// explicitly asked. Run once locally:
    ///
    ///     ORIFOLD_GENERATE_SAMPLE=1 swift test --filter SampleDocumentTests
    func testGenerateSampleDocument() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ORIFOLD_GENERATE_SAMPLE"] == "1")

        let sourceURL = repoRoot().appendingPathComponent("scripts/generate-sample-document.md")
        let markdownData = try Data(contentsOf: sourceURL)

        let imported = try DocumentImportConverter.importedDocument(
            from: markdownData,
            contentType: .markdown,
            filename: "SampleDocument.md",
            baseURL: nil
        )

        XCTAssertGreaterThanOrEqual(imported.pdfDocument.pageCount, 3, "sample must be at least 3 pages")
        let pdfData = try XCTUnwrap(imported.pdfDocument.dataRepresentation(), "could not serialize sample PDF")
        XCTAssertLessThanOrEqual(pdfData.count, 1_500_000, "sample PDF must stay under 1.5 MB")

        let outputURL = repoRoot().appendingPathComponent("Orifold/Resources/SampleDocument.pdf")
        try pdfData.write(to: outputURL)
        print("Wrote \(outputURL.path): \(pdfData.count) bytes, \(imported.pdfDocument.pageCount) pages")
    }

    /// Always-on: the asset is bundled, resolvable via `SampleDocument.url`, opens as a
    /// valid PDF, and carries the onboarding content (≥3 pages).
    func testSampleDocumentBundledAndOpens() throws {
        let url = try XCTUnwrap(SampleDocument.url, "SampleDocument.pdf not found in bundle")
        let doc = try XCTUnwrap(PDFDocument(url: url), "bundled SampleDocument.pdf is not a readable PDF")
        XCTAssertGreaterThanOrEqual(doc.pageCount, 3)
    }
}
