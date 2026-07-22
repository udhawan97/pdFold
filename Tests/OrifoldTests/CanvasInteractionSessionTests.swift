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
        XCTAssertEqual(
            session.plan(for: .escape(hasObjectSelection: true, hasArmedPlacement: false)),
            [.clearObjectSelection, .refreshObjectOverlay]
        )
        XCTAssertTrue(session.plan(for: .escape(hasObjectSelection: false, hasArmedPlacement: false)).isEmpty)
    }

    func testEscapeCancelsAnArmedPlacementBeforeAnySelection() {
        var session = CanvasInteractionSession(initialTool: .stamp)
        XCTAssertEqual(
            session.plan(for: .escape(hasObjectSelection: false, hasArmedPlacement: true)),
            [.cancelArmedPlacement, .refreshSignatureOverlay]
        )
        // An armed placement outranks a selection: the next page click is already spoken
        // for, so backing out of that is what Escape means here.
        XCTAssertEqual(
            session.plan(for: .escape(hasObjectSelection: true, hasArmedPlacement: true)),
            [.cancelArmedPlacement, .refreshSignatureOverlay]
        )
    }
}
