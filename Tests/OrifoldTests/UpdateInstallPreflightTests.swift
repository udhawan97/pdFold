import XCTest
@testable import Orifold

final class UpdateInstallPreflightTests: XCTestCase {
    private typealias Doc = UpdateInstallPreflight.DocumentState

    func testNoOpenDocumentsCanProceed() {
        XCTAssertTrue(UpdateInstallPreflight.canProceed([]))
        XCTAssertTrue(UpdateInstallPreflight.blockingDocuments([]).isEmpty)
    }

    func testAllSavedDocumentsCanProceed() {
        let docs = [
            Doc(displayName: "Report", hasUnsavedChanges: false),
            Doc(displayName: "Invoice", hasUnsavedChanges: false),
        ]
        XCTAssertTrue(UpdateInstallPreflight.canProceed(docs))
    }

    func testUnsavedDocumentBlocksAndIsNamed() {
        let docs = [
            Doc(displayName: "Report", hasUnsavedChanges: false),
            Doc(displayName: "Draft Contract", hasUnsavedChanges: true),
            Doc(displayName: "Notes", hasUnsavedChanges: true),
        ]
        XCTAssertFalse(UpdateInstallPreflight.canProceed(docs))
        XCTAssertEqual(
            UpdateInstallPreflight.blockingDocuments(docs).map(\.displayName),
            ["Draft Contract", "Notes"],
            "only the edited documents block, and they're named so the prompt can list them"
        )
    }
}
