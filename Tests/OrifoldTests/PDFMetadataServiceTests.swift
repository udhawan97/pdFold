import XCTest
import PDFKit
@testable import Orifold

final class PDFMetadataServiceTests: XCTestCase {
    private func fixture(title: String?, author: String?) -> Data {
        let doc = PDFDocument()
        let page = PDFPage()
        doc.insert(page, at: 0)
        var attrs: [PDFDocumentAttribute: Any] = [:]
        if let title { attrs[.titleAttribute] = title }
        if let author { attrs[.authorAttribute] = author }
        doc.documentAttributes = attrs
        return doc.dataRepresentation()!  // fixture creation only — never product code
    }

    func testReadsTitleAndAuthor() throws {
        let data = fixture(title: "折り紙", author: "Gami")
        let meta = try PDFMetadataService.read(from: data, password: nil)
        XCTAssertEqual(meta.title, "折り紙")
        XCTAssertEqual(meta.author, "Gami")
        XCTAssertNil(meta.subject)
    }

    func testMissingInfoDictYieldsAllNil() throws {
        let meta = try PDFMetadataService.read(from: fixture(title: nil, author: nil), password: nil)
        XCTAssertEqual(meta, PDFDocumentMetadata())
    }
}
