import PDFKit
import XCTest
@testable import Orifold

/// Coverage for the "Discard Changes & Close" escape hatch — the way out of the
/// "The file couldn't be saved" dead-end. `revertToInitialState()` must roll every piece
/// of document state back to how it was opened, and `discardChangesAndClose()` must also
/// wipe the undo history so the framework stops treating the window as edited (which is
/// what lets the close skip the failing save-on-close path).
final class DiscardChangesAndCloseTests: XCTestCase {
    private final class FixturePageView: NSView {
        private let text: String
        init(frame: CGRect, text: String) {
            self.text = text
            super.init(frame: frame)
        }
        required init?(coder: NSCoder) { nil }
        override func draw(_ dirtyRect: NSRect) {
            NSColor.white.setFill()
            dirtyRect.fill()
            (text as NSString).draw(
                in: bounds.insetBy(dx: 54, dy: 54),
                withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.black]
            )
        }
    }

    private func makePDFData(pageTexts: [String]) throws -> Data {
        let pdf = PDFDocument()
        for (index, text) in pageTexts.enumerated() {
            let view = FixturePageView(frame: CGRect(x: 0, y: 0, width: 612, height: 792), text: text)
            guard let pageDocument = PDFDocument(data: view.dataWithPDF(inside: view.bounds)),
                  let page = pageDocument.page(at: 0) else {
                throw XCTSkip("fixture page rendering failed")
            }
            pdf.insert(page, at: index)
        }
        return try XCTUnwrap(pdf.dataRepresentation())
    }

    private func makeViewModel(from pdfData: Data, name: String = "Fixture") throws -> WorkspaceViewModel {
        let wrapper = FileWrapper(regularFileWithContents: pdfData)
        wrapper.preferredFilename = "\(name).pdf"
        let document = try WorkspaceDocument(testingFile: wrapper, contentType: .pdf, filename: "\(name).pdf")
        return WorkspaceViewModel(document: document, processingEngine: PDFiumProcessingEngine())
    }

    func testRevertRestoresStructureAfterDelete() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["One", "Two", "Three"]))
        let undoManager = UndoManager()
        viewModel.undoManager = undoManager

        let originalOrder = viewModel.document.workspace.pageOrder.map(\.id)
        XCTAssertEqual(originalOrder.count, 3)

        let lastRef = try XCTUnwrap(viewModel.document.workspace.pageOrder.last)
        viewModel.deletePage(lastRef)
        XCTAssertEqual(viewModel.document.workspace.pageOrder.count, 2, "precondition: a page was removed")
        XCTAssertTrue(viewModel.hasUnsavedChanges, "an edit that registers undo counts as unsaved")

        viewModel.revertToInitialState()

        XCTAssertEqual(viewModel.document.workspace.pageOrder.map(\.id), originalOrder,
                       "revert restores the exact page order the document opened with")
        XCTAssertEqual(viewModel.pageCount, 3, "rebuild ran, so the visible page count is restored")
    }

    func testDiscardAndCloseClearsUndoAndUnsavedFlag() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["One", "Two"]))
        let undoManager = UndoManager()
        viewModel.undoManager = undoManager

        viewModel.rotatePages([try XCTUnwrap(viewModel.document.workspace.pageOrder.first)], by: 90)
        viewModel.deletePage(try XCTUnwrap(viewModel.document.workspace.pageOrder.last))
        XCTAssertTrue(undoManager.canUndo)
        XCTAssertTrue(viewModel.hasUnsavedChanges)

        // hostingWindow is nil in tests, so this reverts + wipes undo without closing anything.
        viewModel.discardChangesAndClose()

        XCTAssertEqual(viewModel.document.workspace.pageOrder.count, 2, "content rolled back to opened state")
        XCTAssertFalse(undoManager.canUndo, "undo history is wiped so the window is no longer edited")
        XCTAssertFalse(undoManager.canRedo)
        XCTAssertFalse(viewModel.hasUnsavedChanges, "a cleared undo stack reads as no unsaved changes")
    }

    func testRevertIsNoOpOnPristineDocument() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["Only"]))
        viewModel.undoManager = UndoManager()

        let orderBefore = viewModel.document.workspace.pageOrder.map(\.id)
        XCTAssertFalse(viewModel.hasUnsavedChanges)

        viewModel.revertToInitialState()

        XCTAssertEqual(viewModel.document.workspace.pageOrder.map(\.id), orderBefore,
                       "reverting an untouched document changes nothing")
        XCTAssertEqual(viewModel.pageCount, 1)
    }
}
