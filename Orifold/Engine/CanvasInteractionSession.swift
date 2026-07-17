import Foundation

/// Pure state machine for canvas event ordering. AppKit remains an adapter: it executes these
/// actions against the view model and overlays, while transition policy stays testable here.
struct CanvasInteractionSession {
    enum Selection: Equatable {
        case object
        case annotation
    }

    enum Event: Equatable {
        case delete(selection: Selection)
        case escape(hasObjectSelection: Bool)
        case viewUpdate(tool: AnnotationTool, hasObjectSelection: Bool)
        case objectMutation
        case pageChanged
        case geometryChanged
    }

    enum Action: Equatable {
        case finishInlineEditing
        case alignUndoManager
        case deleteSelectedObject
        case deleteSelectedAnnotation
        case executeObjectMutation
        case syncDocument
        case clearObjectSelection
        case refreshSignatureOverlay
        case refreshObjectOverlay
        case refreshDecorationOverlays
        case refreshCommentOverlays
        case repaintPDFView
    }

    private var activeTool: AnnotationTool

    init(initialTool: AnnotationTool) {
        activeTool = initialTool
    }

    mutating func plan(for event: Event) -> [Action] {
        switch event {
        case .delete(selection: .object):
            return [
                .alignUndoManager,
                .deleteSelectedObject,
                .syncDocument,
                .refreshObjectOverlay,
                .refreshDecorationOverlays,
                .repaintPDFView
            ]
        case .delete(selection: .annotation):
            return [.deleteSelectedAnnotation, .refreshSignatureOverlay, .refreshDecorationOverlays]
        case .escape(hasObjectSelection: true):
            return [.clearObjectSelection, .refreshObjectOverlay]
        case .escape(hasObjectSelection: false):
            return []
        case .viewUpdate(let tool, let hasObjectSelection):
            var actions: [Action] = []
            if activeTool == .editText, tool != .editText {
                actions.append(.finishInlineEditing)
            }
            actions.append(contentsOf: [.syncDocument, .refreshSignatureOverlay])
            if tool != .selectObject, hasObjectSelection {
                actions.append(.clearObjectSelection)
            }
            actions.append(contentsOf: [
                .refreshObjectOverlay,
                .refreshDecorationOverlays,
                .refreshCommentOverlays
            ])
            activeTool = tool
            return actions
        case .objectMutation:
            return [
                .alignUndoManager,
                .executeObjectMutation,
                .syncDocument,
                .refreshObjectOverlay,
                .repaintPDFView
            ]
        case .pageChanged:
            return [.refreshSignatureOverlay, .refreshCommentOverlays]
        case .geometryChanged:
            return [.refreshSignatureOverlay, .refreshObjectOverlay, .refreshCommentOverlays]
        }
    }
}
