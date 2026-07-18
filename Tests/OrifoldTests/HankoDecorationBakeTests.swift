import AppKit
import PDFKit
import XCTest
@testable import Orifold

/// Feature F3: a `.hanko` page decoration must bake into the exported PDF as a genuinely
/// vermillion seal. The assertion is pixel-based on the rendered thumbnail (CI-safe — never
/// `PDFPage.string`): across the seal region, red must clearly dominate blue where the ink
/// falls, which is what "shu-iro vermillion" means.
final class HankoDecorationBakeTests: XCTestCase {
    func testBakedHankoRendersAVermillionSeal() throws {
        let pageRef = PageRef(memberDocId: UUID(), sourcePageIndex: 0)
        let sealRect = CGRect(x: 210, y: 380, width: 170, height: 170)
        let hanko = PageDecoration.hanko(text: "印", shape: .circle, pageRefID: pageRef.id, rect: sealRect)

        let baked = try PDFDecorationExportBaker.bake(
            decorations: [hanko],
            pageOrder: [pageRef],
            into: blankPageData()
        )

        let reopened = try XCTUnwrap(PDFDocument(data: baked))
        XCTAssertEqual(reopened.pageCount, 1)
        let page = try XCTUnwrap(reopened.page(at: 0))
        let thumbnail = page.thumbnail(of: CGSize(width: 612, height: 792), for: .mediaBox)
        let tiff = try XCTUnwrap(thumbnail.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))

        // Scan a grid over the seal region. A vermillion seal (border ring + kanji) must
        // leave a solid cluster of pixels where red beats blue; a blank page leaves none.
        var vermillionSamples = 0
        for px in stride(from: Int(sealRect.minX), to: Int(sealRect.maxX), by: 6) {
            for py in stride(from: Int(sealRect.minY), to: Int(sealRect.maxY), by: 6) {
                guard let color = bitmap.colorAt(x: px, y: 792 - py)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent > color.blueComponent + 0.2, color.redComponent > 0.4 {
                    vermillionSamples += 1
                }
            }
        }
        XCTAssertGreaterThan(vermillionSamples, 8,
                             "baked hanko should paint a vermillion seal; found \(vermillionSamples) vermillion samples")
    }

    /// A hanko whose `pageRefID` no longer exists is rejected, exactly like a stamp — the
    /// baker never silently drops or mis-places an orphaned seal.
    func testOrphanedHankoIsRejected() throws {
        let hanko = PageDecoration.hanko(text: "印", shape: .square, pageRefID: UUID(), rect: CGRect(x: 10, y: 10, width: 80, height: 80))
        let pageRef = PageRef(memberDocId: UUID(), sourcePageIndex: 0)
        XCTAssertThrowsError(
            try PDFDecorationExportBaker.bake(decorations: [hanko], pageOrder: [pageRef], into: blankPageData())
        )
    }

    private func blankPageData() throws -> Data {
        let page = PDFPage()
        page.setBounds(CGRect(x: 0, y: 0, width: 612, height: 792), for: .mediaBox)
        let doc = PDFDocument()
        doc.insert(page, at: 0)
        return try XCTUnwrap(doc.dataRepresentation())
    }
}
