import SwiftUI
import PDFKit
import Observation

@Observable
final class WorkspaceViewModel {
    var document: WorkspaceDocument
    var combinedPDF: PDFDocument = PDFDocument()
    /// Parallel array to workspace.documents — holds the loaded PDFDocument for each member.
    var loadedPDFs: [(MemberDocument, PDFDocument)] = []

    var importError: ImportError? = nil
    var pendingPasswordURL: URL? = nil
    var isShowingPasswordPrompt = false

    private let engine: PDFKitEngine = PDFKitEngine()

    struct ImportError: Identifiable {
        let id = UUID()
        var fileName: String
        var message: String
    }

    init(document: WorkspaceDocument) {
        self.document = document
    }

    // MARK: - Import

    func importPDFs(urls: [URL]) {
        for url in urls {
            addPDF(from: url)
        }
        rebuild()
    }

    func addPDF(from url: URL) {
        let fileName = url.lastPathComponent
        guard let pdf = engine.loadDocument(from: url) else {
            importError = ImportError(
                fileName: fileName,
                message: "Could not open \"\(fileName)\". The file may be corrupt or in an unsupported format."
            )
            return
        }
        if pdf.isLocked {
            pendingPasswordURL = url
            isShowingPasswordPrompt = true
            return
        }
        attachPDF(pdf, from: url)
    }

    /// Returns true if the password was correct and the document was added.
    func unlock(pdf: PDFDocument, password: String, url: URL) -> Bool {
        guard pdf.unlock(withPassword: password) else { return false }
        attachPDF(pdf, from: url)
        rebuild()
        return true
    }

    private func attachPDF(_ pdf: PDFDocument, from url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        var member = MemberDocument(
            displayName: name,
            sourcePDFRef: url.lastPathComponent
        )
        let refs = (0..<pdf.pageCount).map { i in
            PageRef(memberDocId: member.id, sourcePageIndex: i)
        }
        member.pageRefs = refs.map(\.id)
        document.workspace.documents.append(member)
        document.workspace.pageOrder.append(contentsOf: refs)
        loadedPDFs.append((member, pdf))
    }

    func rebuild() {
        combinedPDF = engine.concatenate(documents: loadedPDFs, includeBanners: true)
    }

    // MARK: - Reorder / Remove

    func moveDocument(from source: IndexSet, to destination: Int) {
        document.workspace.documents.move(fromOffsets: source, toOffset: destination)
        syncLoadedPDFsOrder()
        rebuildPageOrder()
        rebuild()
    }

    func removeDocument(at offsets: IndexSet) {
        let removedIds = Set(offsets.map { document.workspace.documents[$0].id })
        document.workspace.documents.remove(atOffsets: offsets)
        loadedPDFs.removeAll { removedIds.contains($0.0.id) }
        rebuildPageOrder()
        rebuild()
    }

    private func syncLoadedPDFsOrder() {
        let order = document.workspace.documents.map(\.id)
        loadedPDFs.sort { a, b in
            (order.firstIndex(of: a.0.id) ?? Int.max) < (order.firstIndex(of: b.0.id) ?? Int.max)
        }
    }

    private func rebuildPageOrder() {
        document.workspace.pageOrder = document.workspace.documents.flatMap { member in
            document.workspace.pageOrder.filter { $0.memberDocId == member.id }
        }
    }
}
