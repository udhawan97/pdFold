import AppKit
import CoreGraphics
import PDFKit
import XCTest
@testable import Orifold

/// Phase 2/3 core (docs/OBJECT_EDITING_PLAN.md §8.3/§9) — the production write-back engine.
/// Detect real objects → build ops from their stable keys → apply → reopen → re-detect, proving
/// move lands, delete leaves no ghost, untouched colors survive, and the text layer survives.
final class ObjectEditEngineTests: XCTestCase {

    private let imagePDF = CGRect(x: 380, y: 560, width: 60, height: 60)   // moved
    private let blackRect = CGRect(x: 120, y: 120, width: 150, height: 60) // deleted
    private let blueRect = CGRect(x: 300, y: 380, width: 90, height: 50)   // untouched (color check)

    private func makeFixture() -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ctx = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: &mediaBox, nil)!
        ctx.beginPDFPage(nil)
        ctx.setFillColor(NSColor.white.cgColor); ctx.fill(mediaBox)
        ctx.setFillColor(CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)); ctx.fill(blueRect)
        ctx.setFillColor(NSColor.black.cgColor); ctx.fill(blackRect)
        ctx.draw(makeSolidImage(24, 24), in: imagePDF)
        let font = CTFontCreateWithName("Helvetica" as CFString, 16, nil)
        ctx.textPosition = CGPoint(x: 72, y: 700)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(
            string: "ENGINE CANARY", attributes: [.font: font, .foregroundColor: NSColor.black.cgColor])), ctx)
        ctx.endPDFPage(); ctx.closePDF()
        return data as Data
    }

    private func makeSolidImage(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.systemRed.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    private func near(_ a: CGRect, _ b: CGRect, tol: CGFloat = 3) -> Bool {
        abs(a.minX - b.minX) <= tol && abs(a.minY - b.minY) <= tol && abs(a.width - b.width) <= tol && abs(a.height - b.height) <= tol
    }

    private func transformOp(_ o: DetectedObject, dx: CGFloat, dy: CGFloat) -> ObjectEditOperation {
        var newT = o.transform
        newT.e += dx; newT.f += dy
        return ObjectEditOperation(
            type: .objectTransform, documentID: UUID(), pageRefID: o.pageRefID ?? UUID(),
            sourceObjectKey: o.stableKey, objectType: o.objectType, editability: o.editability,
            originalBoundsPdf: o.boundsPdf, newBoundsPdf: o.boundsPdf.offsetBy(dx: dx, dy: dy),
            originalTransform: o.transform, newTransform: newT, pageRotation: Int(o.pageRotation),
            originalZIndex: o.zOrder, newZIndex: o.zOrder, replacementStrategy: .pdfiumStructural)
    }

    private func deleteOp(_ o: DetectedObject) -> ObjectEditOperation {
        ObjectEditOperation(
            type: .objectDelete, documentID: UUID(), pageRefID: o.pageRefID ?? UUID(),
            sourceObjectKey: o.stableKey, objectType: o.objectType, editability: o.editability,
            originalBoundsPdf: o.boundsPdf, newBoundsPdf: o.boundsPdf,
            originalTransform: o.transform, newTransform: o.transform, pageRotation: Int(o.pageRotation),
            originalZIndex: o.zOrder, newZIndex: o.zOrder, replacementStrategy: .pdfiumStructural)
    }

    func testMoveAndDeleteRoundTripThroughRealEngine() throws {
        let pageRefID = UUID()
        let original = makeFixture()
        let before = PDFObjectDetectionEngine.detect(pdfData: original, pageIndex: 0, pageRefID: pageRefID)

        let image = try XCTUnwrap(before.objects.first { $0.objectType == .imageXObject }, "no image detected")
        let blackObj = try XCTUnwrap(before.objects.first { $0.objectType == .rectangle && near($0.boundsPdf, blackRect, tol: 6) }
            ?? before.objects.first { $0.objectType == .filledShape && near($0.boundsPdf, blackRect, tol: 6) }, "no deletable rect")
        let blueObj = try XCTUnwrap(before.objects.first { near($0.boundsPdf, blueRect, tol: 6) }, "no blue rect")
        let blueDigestBefore = blueObj.stableKey.structuralDigest
        XCTAssertNotEqual(blackObj.stableKey, blueObj.stableKey)

        let dx: CGFloat = 80, dy: CGFloat = -30
        let ops = [transformOp(image, dx: dx, dy: dy), deleteOp(blackObj)]
        let result = try XCTUnwrap(PDFObjectEditEngine.apply(operationsByPage: [0: ops], toMember: original), "engine returned nil")
        XCTAssertEqual(result.appliedOpIDs.count, 2, "both ops should apply; unresolved=\(result.unresolvedOpIDs)")
        XCTAssertTrue(result.unresolvedOpIDs.isEmpty)

        // Reopen the produced bytes and re-detect — everything asserted FROM BYTES.
        let after = PDFObjectDetectionEngine.detect(pdfData: result.data, pageIndex: 0, pageRefID: pageRefID)

        // Move landed.
        let movedImage = try XCTUnwrap(after.objects.first { $0.objectType == .imageXObject }, "image vanished")
        XCTAssertTrue(near(movedImage.boundsPdf, imagePDF.offsetBy(dx: dx, dy: dy), tol: 2),
                      "image at \(movedImage.boundsPdf), expected \(imagePDF.offsetBy(dx: dx, dy: dy))")

        // Delete left NO ghost — the black rect's identity is absent from the re-detected graph.
        XCTAssertFalse(after.objects.contains { $0.stableKey.structuralDigest == blackObj.stableKey.structuralDigest && near($0.boundsPdf, blackRect, tol: 6) },
                       "deleted rect still present (ghost)")

        // Untouched blue rect survived, still identifiable, still blue (color-preservation held).
        let blueAfter = try XCTUnwrap(after.objects.first { $0.stableKey.structuralDigest == blueDigestBefore }, "blue rect lost its identity")
        let fill = try XCTUnwrap(blueAfter.style.fillColor, "blue rect lost its fill color")
        XCTAssertGreaterThan(fill.blue, 0.6, "blue rect no longer blue (color dropped by GenerateContent)")
        XCTAssertLessThan(fill.red, 0.4)

        // Text layer survived the whole-stream rebuild (attributedString, per CI quirk).
        let reopenedText = PDFDocument(data: result.data)?.page(at: 0)?.attributedString?.string ?? ""
        XCTAssertTrue(reopenedText.contains("CANARY"), "text layer dropped by the write-back")
    }

    // Applying an op whose target isn't on the page resolves to "unresolved", never a crash/failure.
    func testUnresolvedOpIsReportedNotFatal() {
        let original = makeFixture()
        let bogus = ObjectEditOperation(
            type: .objectDelete, documentID: UUID(), pageRefID: UUID(),
            sourceObjectKey: PDFObjectStableKey(pageRefID: UUID(), structuralDigest: 0xDEAD_BEEF),
            objectType: .rectangle, editability: .directVectorEdit,
            originalBoundsPdf: .zero, newBoundsPdf: .zero, originalTransform: .identity, newTransform: .identity,
            pageRotation: 0, originalZIndex: 0, newZIndex: 0, replacementStrategy: .pdfiumStructural)
        let result = PDFObjectEditEngine.apply(operationsByPage: [0: [bogus]], toMember: original)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.appliedOpIDs.isEmpty ?? false)
        XCTAssertEqual(result?.unresolvedOpIDs, [bogus.id])
    }

    // Empty op map is a no-op returning the member unchanged; a malformed member can't load.
    func testDegradesGracefully() {
        let original = makeFixture()
        let noOps = PDFObjectEditEngine.apply(operationsByPage: [:], toMember: original)
        XCTAssertEqual(noOps?.data, original, "empty op map should return the member bytes unchanged")

        let bogus = ObjectEditOperation(
            type: .objectDelete, documentID: UUID(), pageRefID: UUID(),
            sourceObjectKey: PDFObjectStableKey(pageRefID: UUID(), structuralDigest: 1),
            objectType: .rectangle, editability: .directVectorEdit,
            originalBoundsPdf: .zero, newBoundsPdf: .zero, originalTransform: .identity, newTransform: .identity,
            pageRotation: 0, originalZIndex: 0, newZIndex: 0, replacementStrategy: .pdfiumStructural)
        XCTAssertNil(PDFObjectEditEngine.apply(operationsByPage: [0: [bogus]], toMember: Data("not a pdf".utf8)),
                     "a member that can't be loaded returns nil")
    }
}
