import PDFKit
import XCTest
@testable import Orifold

/// Feature C (read-aloud): a document mutated while speaking invalidates the controller's
/// snapshot — its chunk offsets and page index were captured against the old `combinedPDF`,
/// so after a delete/insert/reorder/undo the follow-along highlight would land on the wrong
/// page or out of bounds. Read-aloud must auto-stop whenever the document is rebuilt.
///
/// The controller is backed by a fake synthesizer (no real audio device — matching
/// `AVSpeechSynthesizerAdapterTests`) and canned page text, so `start` is deterministic and
/// independent of live PDF text extraction; the wiring under test is that `rebuild()` stops
/// whichever controller is installed.
@MainActor
final class ReadAloudDocumentMutationTests: XCTestCase {

    /// Deterministic stand-in for `AVSpeechSynthesizer`; never touches an audio device.
    private final class FakeSynthesizer: SpeechSynthesizing {
        var onWillSpeakRange: ((NSRange) -> Void)?
        var onFinishUtterance: (() -> Void)?
        private(set) var stopCount = 0
        func speak(_ text: String, rate: Float) {}
        func pause() {}
        func resume() {}
        func stopSpeaking() { stopCount += 1 }
    }

    /// Minimal drawable page so the fixture PDF has real, deletable pages.
    private final class FixturePageView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.white.setFill()
            dirtyRect.fill()
            ("Page" as NSString).draw(
                at: NSPoint(x: 72, y: 72),
                withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.black]
            )
        }
    }

    private func makeViewModel(pageCount: Int) throws -> WorkspaceViewModel {
        let pdf = PDFDocument()
        for index in 0..<pageCount {
            let view = FixturePageView(frame: CGRect(x: 0, y: 0, width: 612, height: 792))
            guard let doc = PDFDocument(data: view.dataWithPDF(inside: view.bounds)),
                  let page = doc.page(at: 0) else {
                throw XCTSkip("fixture page rendering failed")
            }
            pdf.insert(page, at: index)
        }
        let data = try XCTUnwrap(pdf.dataRepresentation())
        let wrapper = FileWrapper(regularFileWithContents: data)
        wrapper.preferredFilename = "ReadAloudFixture.pdf"
        let document = try WorkspaceDocument(testingFile: wrapper, contentType: .pdf, filename: "ReadAloudFixture.pdf")
        return WorkspaceViewModel(document: document, processingEngine: PDFiumProcessingEngine())
    }

    private func startedReadAloud(on viewModel: WorkspaceViewModel) -> (ReadAloudController, FakeSynthesizer) {
        let synth = FakeSynthesizer()
        let controller = viewModel.installReadAloudControllerForTesting(
            synthesizer: synth,
            pageText: { _ in "Alpha one. Alpha two." },
            pageCount: { 3 }
        )
        controller.start(fromPage: 0)
        return (controller, synth)
    }

    /// `rebuild()` is the single choke point every structural mutation passes through; stopping
    /// read-aloud there covers delete/insert/reorder/duplicate/undo in one place.
    func testRebuildStopsActiveReadAloud() throws {
        let viewModel = try makeViewModel(pageCount: 3)
        let (controller, synth) = startedReadAloud(on: viewModel)
        XCTAssertEqual(controller.state, .speaking, "precondition: read-aloud must be speaking before the mutation")

        viewModel.rebuild()

        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.highlight)
        XCTAssertEqual(synth.stopCount, 1)
    }

    /// End-to-end via a real structural op: deleting a page routes through `rebuild()`.
    func testDeletingPageStopsActiveReadAloud() throws {
        let viewModel = try makeViewModel(pageCount: 3)
        let (controller, _) = startedReadAloud(on: viewModel)
        XCTAssertEqual(controller.state, .speaking)

        let firstRef = try XCTUnwrap(viewModel.document.workspace.pageOrder.first)
        viewModel.deletePage(firstRef)

        XCTAssertEqual(controller.state, .idle)
    }

    /// A controller that is not active must not have `stop()` needlessly driven on a rebuild
    /// (and rebuild must never force the lazy controller into existence for an idle document).
    func testRebuildDoesNotStopIdleReadAloud() throws {
        let viewModel = try makeViewModel(pageCount: 2)
        let synth = FakeSynthesizer()
        _ = viewModel.installReadAloudControllerForTesting(synthesizer: synth, pageText: { _ in "A." }, pageCount: { 2 })

        viewModel.rebuild()

        XCTAssertEqual(synth.stopCount, 0)
    }
}
