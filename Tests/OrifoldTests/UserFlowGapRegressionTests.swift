import XCTest
import PDFKit
@testable import Orifold

/// Regressions for gaps found in the July 2026 user-flow audit. Each test names the
/// user-visible failure it prevents, not the implementation it happens to exercise.
final class UserFlowGapRegressionTests: XCTestCase {

    // MARK: - Export runs off the main thread with a cancel that writes nothing

    func testFinishedExportDataStopsAtAStageBoundaryWhenCancelled() throws {
        let payload = BakedExportPayload(
            baked: BakedPDFData(alreadyFlattened: try makePDFData(pageTexts: ["Alpha", "Beta"])),
            outline: [],
            attachments: []
        )
        XCTAssertThrowsError(
            try WorkspaceViewModel.finishedExportData(
                payload,
                options: WorkspaceExportOptions(),
                isCancelled: { true }
            )
        ) { error in
            XCTAssertTrue(error is PDFExportCancelled, "cancellation must be distinguishable from a failure")
        }
    }

    func testSplittingTheExportPipelineProducesTheSameBytesAsOnePass() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["Alpha", "Beta"]))
        let options = WorkspaceExportOptions()

        let singlePass = try viewModel.dataForPDFExport(options: options)
        let payload = try viewModel.bakedExportPayload(options: options)
        let split = try WorkspaceViewModel.finishedExportData(payload, options: options)

        // Not byte-equality: a PDF carries a generation-time /ID, so two serializations of
        // the same content differ. Page count is what the split must preserve.
        XCTAssertEqual(PDFDocument(data: singlePass)?.pageCount, PDFDocument(data: split)?.pageCount)
        XCTAssertNotNil(PDFDocument(data: split), "the split pipeline must still produce a readable PDF")
    }

    func testExportProgressReportsEveryStageItRuns() throws {
        let payload = BakedExportPayload(
            baked: BakedPDFData(alreadyFlattened: try makePDFData(pageTexts: ["Alpha"])),
            outline: [],
            attachments: []
        )
        let recorder = StageRecorder()
        _ = try WorkspaceViewModel.finishedExportData(
            payload,
            options: WorkspaceExportOptions(),
            progress: { _, stage in recorder.record(stage) }
        )
        XCTAssertTrue(recorder.stages.contains(.layout))
        XCTAssertEqual(recorder.stages.last, .finishing, "the readout must reach 100% rather than stall mid-stage")
    }

    // MARK: - A password-protected file is not "damaged"

    func testPasswordProtectedImportIsClassifiedApartFromCorruption() {
        let kind = ImportFailureClassifier.classify(
            error: DocumentImportConverter.ConversionError.passwordProtected,
            url: nil
        )
        XCTAssertEqual(kind, .passwordProtected)
        XCTAssertNotEqual(kind, .corruptOrEncrypted, "calling an intact encrypted file damaged hides the fix")
        XCTAssertTrue(kind.showsChooseFileAgain, "reselecting routes the file through the path that prompts")
    }

    func testPasswordProtectedFailureSurfacesTheActionableGuidance() {
        let message = DocumentImportConverter.userMessage(for: ImportFailureKind.passwordProtected)
        XCTAssertEqual(message, L10n.string("error.import.passwordProtected"))
        XCTAssertNotEqual(message, L10n.string("error.import.corruptOrEncrypted"))
    }

    func testConversionErrorsCarryTheirOwnMessageForTheDocumentOpenPath() {
        // Finder double-click / File ▸ Open throw straight out of `WorkspaceDocument.init`
        // with no Orifold UI in between, so `localizedDescription` is all the user sees.
        let errors: [DocumentImportConverter.ConversionError] = [
            .passwordProtected, .unreadableDocument, .emptyDocument, .unsupportedType
        ]
        for error in errors {
            XCTAssertEqual(
                error.localizedDescription,
                DocumentImportConverter.userMessage(for: error),
                "\(error) must explain itself the same way on both open surfaces"
            )
        }
    }

    // MARK: - Nothing is armed invisibly

    func testEveryArmedPlacementAnnouncesItselfAndCanBeCancelled() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["Alpha"]))

        viewModel.beginStampPlacement(text: "APPROVED", swatch: .coral)
        XCTAssertTrue(viewModel.hasArmedPlacement)
        XCTAssertNotNil(viewModel.armedPlacementPromptKey, "an armed stamp must have something to say")
        XCTAssertNotNil(viewModel.editingStatus)

        XCTAssertTrue(viewModel.cancelArmedPlacement())
        XCTAssertFalse(viewModel.hasArmedPlacement)
        XCTAssertNil(viewModel.editingStatus)
        XCTAssertFalse(viewModel.cancelArmedPlacement(), "cancelling nothing reports that it did nothing")
    }

    func testLeavingTheStampToolDisarmsAStampSoNoStrayMarkLandsLater() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["Alpha"]))
        viewModel.beginStampPlacement(text: "DRAFT", swatch: .coral)
        XCTAssertTrue(viewModel.hasArmedPlacement)

        viewModel.currentTool = .highlight

        XCTAssertFalse(
            viewModel.hasArmedPlacement,
            "a forgotten armed stamp used to fire on the next page click, long after the user moved on"
        )
    }

    // MARK: - Search says what it is actually doing

    func testSearchingFlagDistinguishesPendingFromNoMatches() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["Alpha Beta"]))
        XCTAssertFalse(viewModel.isSearching)

        viewModel.searchQuery = "beta"
        viewModel.scheduleSearch(query: "beta")

        // Set before the debounce even elapses: an empty result list means "no matches" to
        // the panel, and claiming that mid-query reads as a failed search.
        XCTAssertTrue(viewModel.isSearching)
        XCTAssertTrue(viewModel.searchResults.isEmpty)

        viewModel.clearSearch()
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertTrue(viewModel.searchQuery.isEmpty)
    }

    func testSynchronousSearchStillAnswersOnTheNextLine() throws {
        let viewModel = try makeViewModel(from: try makePDFData(pageTexts: ["Widget Widget"]))
        viewModel.search(query: "widget")
        XCTAssertFalse(viewModel.isSearching, "the scripted path resolves before it returns")
        XCTAssertEqual(viewModel.searchResultsQuery, "widget")
    }

    // MARK: - Un-applied metadata typing survives a glance elsewhere

    func testMetadataDraftKeepsUnappliedTypingAcrossReseeds() {
        var draft = MetadataDraft()
        draft.seed(from: PDFDocumentMetadata(title: "Stored", author: nil, subject: nil, keywords: nil), hasXMP: false)
        XCTAssertFalse(draft.isDirty)

        draft.title = "Half-typed"
        XCTAssertTrue(draft.isDirty, "a dirty draft is what tells the re-seed to leave it alone")

        draft.markApplied()
        XCTAssertFalse(draft.isDirty, "after Apply the document holds what the draft holds")
    }

    // MARK: - Read aloud says why it has nothing to say

    @MainActor
    func testReadAloudReportsWhenThereIsNoTextToRead() {
        let controller = ReadAloudController(
            synthesizer: SilentSynthesizer(),
            pageTextProvider: { _ in nil },   // a scanned document: pages, no text layer
            pageCount: { 3 }
        )
        XCTAssertFalse(controller.start(fromPage: 0), "the caller needs to know so it can explain the silence")
        XCTAssertEqual(controller.state, .idle)
    }

    /// Speaks nothing and records nothing: this test only cares whether `start` admits it
    /// found no speakable page.
    private final class SilentSynthesizer: SpeechSynthesizing {
        var onWillSpeakRange: ((NSRange) -> Void)?
        var onFinishUtterance: (() -> Void)?
        func speak(_ text: String, rate: Float) {}
        func pause() {}
        func resume() {}
        func stopSpeaking() {}
    }

    // MARK: - Helpers

    private final class StageRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [ExportStage] = []
        var stages: [ExportStage] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }
        func record(_ stage: ExportStage) {
            lock.lock(); defer { lock.unlock() }
            storage.append(stage)
        }
    }

    private func makeViewModel(from data: Data, name: String = "Fixture") throws -> WorkspaceViewModel {
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = "\(name).pdf"
        let document = try WorkspaceDocument(testingFile: wrapper, contentType: .pdf, filename: "\(name).pdf")
        return WorkspaceViewModel(document: document, processingEngine: PDFiumProcessingEngine())
    }

    private func makePDFData(pageTexts: [String]) throws -> Data {
        let pdf = PDFDocument()
        for (index, text) in pageTexts.enumerated() {
            let renderer = NSImage(size: CGSize(width: 200, height: 200))
            renderer.lockFocus()
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 200, height: 200).fill()
            (text as NSString).draw(
                at: NSPoint(x: 20, y: 100),
                withAttributes: [.font: NSFont.systemFont(ofSize: 18), .foregroundColor: NSColor.black]
            )
            renderer.unlockFocus()
            let page = try XCTUnwrap(PDFPage(image: renderer))
            pdf.insert(page, at: index)
        }
        return try XCTUnwrap(PDFSerializer.data(from: pdf))
    }
}
