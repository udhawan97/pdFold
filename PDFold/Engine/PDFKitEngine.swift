import PDFKit
import Foundation

final class PDFKitEngine: PDFEngine {
    func loadDocument(from url: URL) -> PDFDocument? {
        PDFDocument(url: url)
    }

    /// Concatenate member documents into one PDFDocument for display.
    /// Each member is preceded by a styled BoundaryPage header.
    /// Pass `includeBanners: false` to build a plain export PDF.
    func concatenate(documents: [(MemberDocument, PDFDocument)], includeBanners: Bool = true) -> PDFDocument {
        let combined = PDFDocument()
        var insertIndex = 0
        for (member, pdf) in documents {
            if includeBanners {
                let width = pdf.page(at: 0)?.bounds(for: .mediaBox).width ?? 612
                let banner = BoundaryPage(
                    documentName: member.displayName,
                    pageCount: pdf.pageCount,
                    width: width
                )
                combined.insert(banner, at: insertIndex)
                insertIndex += 1
            }
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    combined.insert(page, at: insertIndex)
                    insertIndex += 1
                }
            }
        }
        return combined
    }
}
