import PDFKit
import Foundation

protocol PDFEngine {
    func loadDocument(from url: URL) -> PDFDocument?
    func concatenate(documents: [(MemberDocument, PDFDocument)], includeBanners: Bool) -> PDFDocument
}
