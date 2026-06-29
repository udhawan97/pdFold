import SwiftUI
import PDFKit
import Observation

enum AnnotationTool: String, CaseIterable, Identifiable {
    case none      = "cursor.arrow"
    case highlight = "highlighter"
    case note      = "note.text"
    case ink       = "pencil.tip"
    case signature = "signature"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Select"
        case .highlight: return "Highlight"
        case .note: return "Note"
        case .ink: return "Ink"
        case .signature: return "Signature"
        }
    }
}

@Observable
final class WorkspaceViewModel {
    var document: WorkspaceDocument
    var combinedPDF: PDFDocument = PDFDocument()
    /// Ordered parallel to workspace.documents.
    var loadedPDFs: [(MemberDocument, PDFDocument)] = []

    // MARK: - UI state
    var importError: ImportError? = nil
    var pendingPasswordURL: URL? = nil
    var isShowingPasswordPrompt = false
    var currentTool: AnnotationTool = .none
    var isShowingExport = false
    var isShowingSearch = false
    var isShowingSignaturePalette = false
    var searchQuery = ""
    var searchResults: [PDFSelection] = []
    var pendingSignatureData: Data? = nil

    weak var undoManager: UndoManager?

    private let engine = PDFKitEngine()

    struct ImportError: Identifiable {
        let id = UUID()
        var fileName: String
        var message: String
    }

    // MARK: - Init

    init(document: WorkspaceDocument) {
        self.document = document

        // Reconstruct loadedPDFs from saved package data (document open path)
        for member in document.workspace.documents {
            if let data = document.memberPDFData[member.id],
               let pdf = PDFDocument(data: data) {
                loadedPDFs.append((member, pdf))
            }
        }

        // Snapshot hook: bake live annotation state before each save
        document.currentPDFDataProvider = { [weak self] in
            guard let self else { return [:] }
            var result: [UUID: Data] = [:]
            for (member, pdf) in self.loadedPDFs {
                result[member.id] = pdf.dataRepresentation()
            }
            return result
        }

        if !loadedPDFs.isEmpty { rebuild() }
    }

    // MARK: - Import

    func importPDFs(urls: [URL]) {
        for url in urls { addPDF(from: url) }
        rebuild()
    }

    func addPDF(from url: URL) {
        let fileName = url.lastPathComponent
        guard let pdf = engine.loadDocument(from: url) else {
            importError = ImportError(fileName: fileName,
                message: "Could not open \"\(fileName)\". The file may be corrupt or in an unsupported format.")
            return
        }
        if pdf.isLocked {
            pendingPasswordURL = url
            isShowingPasswordPrompt = true
            return
        }
        attachPDF(pdf, from: url)
    }

    func unlock(pdf: PDFDocument, password: String, url: URL) -> Bool {
        guard pdf.unlock(withPassword: password) else { return false }
        attachPDF(pdf, from: url)
        rebuild()
        return true
    }

    private func attachPDF(_ pdf: PDFDocument, from url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        var member = MemberDocument(displayName: name, sourcePDFRef: url.lastPathComponent)
        let refs = (0..<pdf.pageCount).map { i in PageRef(memberDocId: member.id, sourcePageIndex: i) }
        member.pageRefs = refs.map(\.id)
        document.workspace.documents.append(member)
        document.workspace.pageOrder.append(contentsOf: refs)
        document.memberPDFData[member.id] = pdf.dataRepresentation()
        loadedPDFs.append((member, pdf))
    }

    func rebuild() {
        combinedPDF = engine.concatenate(documents: loadedPDFs, includeBanners: true)
    }

    // MARK: - Reorder / Remove (with undo)

    func moveDocument(from source: IndexSet, to destination: Int) {
        let snapshot = captureOrderSnapshot()
        document.workspace.documents.move(fromOffsets: source, toOffset: destination)
        syncLoadedPDFsOrder()
        rebuildPageOrder()
        rebuild()
        registerUndo(snapshot: snapshot, actionName: "Move Document")
    }

    func removeDocument(at offsets: IndexSet) {
        let snapshot = captureOrderSnapshot()
        let removedIds = Set(offsets.map { document.workspace.documents[$0].id })
        document.workspace.documents.remove(atOffsets: offsets)
        loadedPDFs.removeAll { removedIds.contains($0.0.id) }
        rebuildPageOrder()
        rebuild()
        registerUndo(snapshot: snapshot, actionName: "Remove Document")
    }

    private struct OrderSnapshot {
        var documents: [MemberDocument]
        var pageOrder: [PageRef]
        var loadedPDFs: [(MemberDocument, PDFDocument)]
    }

    private func captureOrderSnapshot() -> OrderSnapshot {
        OrderSnapshot(
            documents: document.workspace.documents,
            pageOrder: document.workspace.pageOrder,
            loadedPDFs: loadedPDFs
        )
    }

    private func registerUndo(snapshot: OrderSnapshot, actionName: String) {
        undoManager?.registerUndo(withTarget: self) { vm in
            vm.document.workspace.documents = snapshot.documents
            vm.document.workspace.pageOrder = snapshot.pageOrder
            vm.loadedPDFs = snapshot.loadedPDFs
            vm.rebuild()
        }
        undoManager?.setActionName(actionName)
    }

    private func syncLoadedPDFsOrder() {
        let order = document.workspace.documents.map(\.id)
        loadedPDFs.sort {
            (order.firstIndex(of: $0.0.id) ?? Int.max) < (order.firstIndex(of: $1.0.id) ?? Int.max)
        }
    }

    private func rebuildPageOrder() {
        document.workspace.pageOrder = document.workspace.documents.flatMap { member in
            document.workspace.pageOrder.filter { $0.memberDocId == member.id }
        }
    }

    // MARK: - Annotations

    func applyHighlight(to selection: PDFSelection, color: NSColor = .yellow) {
        selection.selectionsByLine().forEach { line in
            guard let page = line.pages.first else { return }
            let bounds = line.bounds(for: page)
            let ann = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            ann.color = color.withAlphaComponent(0.4)
            page.addAnnotation(ann)
            undoManager?.registerUndo(withTarget: self) { _ in page.removeAnnotation(ann) }
        }
        undoManager?.setActionName("Highlight")
    }

    func addNote(at pagePoint: CGPoint, on page: PDFPage) {
        let size: CGFloat = 24
        let bounds = CGRect(x: pagePoint.x - size / 2, y: pagePoint.y - size / 2,
                            width: size, height: size)
        let ann = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        ann.contents = ""
        ann.color = .yellow
        page.addAnnotation(ann)
        undoManager?.registerUndo(withTarget: self) { _ in page.removeAnnotation(ann) }
        undoManager?.setActionName("Add Note")
    }

    func addInkStroke(path: NSBezierPath, on page: PDFPage, color: NSColor = NSColor.systemBlue) {
        let bounds = path.bounds.insetBy(dx: -2, dy: -2)
        let ann = PDFAnnotation(bounds: bounds, forType: .ink, withProperties: nil)
        ann.color = color
        ann.border = PDFBorder()
        ann.border?.lineWidth = 2
        // Store path points via the PDF annotation dictionary
        let flatPoints = bezierPathToFlatPoints(path)
        ann.setValue(flatPoints, forAnnotationKey: PDFAnnotationKey(rawValue: "/InkList"))
        page.addAnnotation(ann)
        undoManager?.registerUndo(withTarget: self) { _ in page.removeAnnotation(ann) }
        undoManager?.setActionName("Ink Stroke")
    }

    private func bezierPathToFlatPoints(_ path: NSBezierPath) -> [[CGFloat]] {
        var result: [CGFloat] = []
        var pts = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<path.elementCount {
            let type = path.element(at: i, associatedPoints: &pts)
            switch type {
            case .moveTo, .lineTo:
                result.append(contentsOf: [pts[0].x, pts[0].y])
            case .curveTo:
                result.append(contentsOf: [pts[2].x, pts[2].y])
            case .closePath:
                break
            @unknown default:
                break
            }
        }
        return [result]  // single-stroke array
    }

    // MARK: - Signature

    func placeSignature(imageData: Data, at pagePoint: CGPoint, on page: PDFPage, size: CGSize = CGSize(width: 120, height: 48)) {
        let bounds = CGRect(
            x: pagePoint.x - size.width / 2,
            y: pagePoint.y - size.height / 2,
            width: size.width, height: size.height
        )
        let placement = SignaturePlacement(
            pageRefId: pageRefID(for: page),
            imageData: imageData,
            rect: bounds,
            signedAt: Date()
        )
        document.workspace.signatures.append(placement)

        // Render as a stamp annotation for display
        if let image = NSImage(data: imageData) {
            let ann = PDFAnnotation(bounds: bounds, forType: .stamp, withProperties: nil)
            ann.setValue(image, forAnnotationKey: .widgetValue)
            page.addAnnotation(ann)
        }
        undoManager?.setActionName("Place Signature")
    }

    private func pageRefID(for page: PDFPage) -> UUID {
        // Map the PDFPage back to a PageRef.id using position in combinedPDF
        guard let doc = page.document,
              let idx = (0..<doc.pageCount).first(where: { doc.page(at: $0) === page })
        else { return UUID() }
        // The combinedPDF interleaves banner pages; skip them
        var realPageIdx = 0
        for i in 0..<idx {
            if !(doc.page(at: i) is BoundaryPage) { realPageIdx += 1 }
        }
        let refs = document.workspace.pageOrder
        guard realPageIdx < refs.count else { return UUID() }
        return refs[realPageIdx].id
    }

    // MARK: - Search

    func search(query: String) {
        searchResults = []
        guard !query.isEmpty else { return }
        combinedPDF.cancelFindString()
        let results = combinedPDF.findString(query, withOptions: .caseInsensitive)
        searchResults = results
    }

    // MARK: - Export

    func exportPlainPDF() {
        let exportDoc = engine.concatenate(documents: loadedPDFs, includeBanners: false)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(document.workspace.title).pdf"
        panel.title = "Export as PDF"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exportDoc.write(to: url)
    }
}
