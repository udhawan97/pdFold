import Foundation
import AppKit

/// Decides whether an update install may proceed without risking unsaved work.
///
/// The decision logic is a pure function over a snapshot of open documents so it can be
/// unit-tested; the live bridge that reads `NSDocumentController` is a thin, separate
/// layer. An install must NEVER close or replace the app while any document has unsaved
/// changes — this is what the future install flow calls to gate that step and drive the
/// "save these first" prompt.
enum UpdateInstallPreflight {
    /// A minimal, value-type view of one open document — enough to decide and to name in a
    /// prompt, without depending on `NSDocument` in tests.
    struct DocumentState: Equatable {
        var displayName: String
        var hasUnsavedChanges: Bool
    }

    /// The documents that must be saved or closed before an install can safely proceed.
    static func blockingDocuments(_ documents: [DocumentState]) -> [DocumentState] {
        documents.filter(\.hasUnsavedChanges)
    }

    /// True only when no open document would lose work if the app were replaced/relaunched.
    static func canProceed(_ documents: [DocumentState]) -> Bool {
        blockingDocuments(documents).isEmpty
    }

    /// Live snapshot of the app's open documents. Kept separate from the pure logic above
    /// so the decision stays testable.
    @MainActor
    static func openDocumentsSnapshot(controller: NSDocumentController = .shared) -> [DocumentState] {
        controller.documents.map {
            DocumentState(
                displayName: $0.displayName ?? L10n.string("document.untitledWorkspace"),
                hasUnsavedChanges: $0.isDocumentEdited
            )
        }
    }
}
