import XCTest
@testable import Orifold

final class CanvasInteractionSessionTests: XCTestCase {
    func testObjectDeletePlanOwnsMutationAndRefreshOrder() {
        var session = CanvasInteractionSession(initialTool: .selectObject)

        XCTAssertEqual(
            session.plan(for: .delete(selection: .object)),
            [
                .alignUndoManager,
                .deleteSelectedObject,
                .syncDocument,
                .refreshObjectOverlay,
                .refreshDecorationOverlays,
                .repaintPDFView
            ]
        )
    }

    func testToolTransitionFinishesTextAndClearsObjectBeforeRefresh() {
        var session = CanvasInteractionSession(initialTool: .editText)

        XCTAssertEqual(
            session.plan(for: .viewUpdate(tool: .highlight, hasObjectSelection: true)),
            [
                .finishInlineEditing,
                .syncDocument,
                .refreshSignatureOverlay,
                .clearObjectSelection,
                .refreshObjectOverlay,
                .refreshDecorationOverlays,
                .refreshCommentOverlays
            ]
        )
    }

    func testEscapeIsConsumedOnlyForAnObjectSelection() {
        var session = CanvasInteractionSession(initialTool: .selectObject)
        XCTAssertEqual(session.plan(for: .escape(hasObjectSelection: true)), [.clearObjectSelection, .refreshObjectOverlay])
        XCTAssertTrue(session.plan(for: .escape(hasObjectSelection: false)).isEmpty)
    }
}
