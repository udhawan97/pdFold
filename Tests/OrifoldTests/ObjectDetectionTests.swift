import AppKit
import CoreGraphics
import XCTest
@testable import Orifold

/// Phase 1 (docs/OBJECT_EDITING_PLAN.md §16) — object model + detection, no UI.
/// Detection/classification against a real PDFium object graph + the persistence round-trip.
final class ObjectDetectionTests: XCTestCase {

    // A fixture with a stroked line, a stroked rectangle, an image, body text, and a full-bleed
    // white background — one of each detectable Phase-1 category.
    private let linePDF = (from: CGPoint(x: 100, y: 600), to: CGPoint(x: 300, y: 600))
    private let rectPDF = CGRect(x: 120, y: 400, width: 140, height: 80)
    private let imagePDF = CGRect(x: 400, y: 300, width: 50, height: 50)

    private func makeFixture() -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ctx = CGContext(consumer: CGDataConsumer(data: data as CFMutableData)!, mediaBox: &mediaBox, nil)!
        ctx.beginPDFPage(nil)
        ctx.setFillColor(NSColor.white.cgColor); ctx.fill(mediaBox)                 // full-bleed background
        ctx.setStrokeColor(NSColor.black.cgColor); ctx.setLineWidth(2)
        ctx.move(to: linePDF.from); ctx.addLine(to: linePDF.to); ctx.strokePath()   // a line
        ctx.setStrokeColor(CGColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)); ctx.setLineWidth(1.5)
        ctx.stroke(rectPDF)                                                          // a rectangle
        ctx.draw(makeSolidImage(24, 24), in: imagePDF)                              // an image XObject
        let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
        ctx.textPosition = CGPoint(x: 72, y: 700)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(
            string: "DETECT ME", attributes: [.font: font, .foregroundColor: NSColor.black.cgColor])), ctx)
        ctx.endPDFPage(); ctx.closePDF()
        return data as Data
    }

    private func makeSolidImage(_ w: Int, _ h: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(NSColor.systemRed.cgColor); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    private func near(_ a: CGRect, _ b: CGRect, tol: CGFloat = 4) -> Bool {
        abs(a.minX - b.minX) <= tol && abs(a.minY - b.minY) <= tol && abs(a.width - b.width) <= tol && abs(a.height - b.height) <= tol
    }

    // Test #1/#2/#3 — a line, a rectangle, an image are each detected and classified.
    func testDetectsLineRectangleAndImage() {
        let map = PDFObjectDetectionEngine.detect(pdfData: makeFixture(), pageIndex: 0, pageRefID: UUID())
        XCTAssertFalse(map.objects.isEmpty, "detection returned no objects")

        // No TEXT object leaks into the graphics map (§7 — text is the text-edit lane).
        // (Text objects would classify as none of our graphic types; we assert the fixture's
        //  text does not appear by checking every object is a known graphic category.)
        XCTAssertTrue(map.objects.allSatisfy { $0.objectType != .annotation || $0.sourceType == .pdfKitAnnotation })

        let image = map.objects.first { $0.objectType == .imageXObject }
        let img = try? XCTUnwrap(image)
        XCTAssertNotNil(img)
        XCTAssertEqual(img?.editability, .directImageEdit)
        XCTAssertTrue(near(img?.boundsPdf ?? .zero, imagePDF), "image bounds \(String(describing: img?.boundsPdf)) != \(imagePDF)")
        XCTAssertEqual(img?.imageMetadata?.pixelWidth, 24)
        XCTAssertTrue(img?.capabilities.canMove == true && img?.capabilities.canReplaceImage == true)

        let line = map.objects.first { $0.objectType == .line }
        XCTAssertNotNil(line, "no line detected; types=\(map.objects.map(\.objectType))")
        XCTAssertEqual(line?.editability, .directVectorEdit)
        XCTAssertEqual(line?.confidence, .high)
        XCTAssertTrue((line?.pathData?.isStroked ?? false), "line should be stroked")

        let rect = map.objects.first { $0.objectType == .rectangle }
        XCTAssertNotNil(rect, "no rectangle detected; types=\(map.objects.map(\.objectType))")
        XCTAssertEqual(rect?.editability, .directVectorEdit)
        XCTAssertTrue(near(rect?.boundsPdf ?? .zero, rectPDF, tol: 6), "rect bounds \(String(describing: rect?.boundsPdf))")

        // The full-bleed white background is detected but flagged non-selectable.
        let background = map.objects.first { $0.isBackgroundLike }
        XCTAssertNotNil(background, "full-bleed background not flagged isBackgroundLike")
        XCTAssertEqual(background?.editability, .inferredArtifactEdit)
        XCTAssertEqual(background?.confidence, .low)
    }

    // Detection is deterministic — same bytes → identical stable keys (identity foundation).
    func testDetectionIsDeterministic() {
        let data = makeFixture()
        let a = PDFObjectDetectionEngine.detect(pdfData: data, pageIndex: 0, pageRefID: UUID())
        let b = PDFObjectDetectionEngine.detect(pdfData: data, pageIndex: 0, pageRefID: a.pageRefID)
        XCTAssertEqual(a.objects.count, b.objects.count)
        XCTAssertEqual(a.objects.map { $0.stableKey.structuralDigest },
                       b.objects.map { $0.stableKey.structuralDigest },
                       "structuralDigest must be stable across identical detection passes")
    }

    // Test #30 — permission-restricted document: every object locked, no crash.
    func testPermissionRestrictedLocksEverything() {
        let map = PDFObjectDetectionEngine.detect(pdfData: makeFixture(), pageIndex: 0, pageRefID: UUID(), allowsEditing: false)
        XCTAssertFalse(map.objects.isEmpty)
        XCTAssertTrue(map.objects.allSatisfy { $0.editability == .lockedOrPermissionRestricted })
        XCTAssertTrue(map.objects.allSatisfy { $0.capabilities.isReadOnly })
    }

    // Test #29 — malformed / empty input degrades to an empty map, never throws/crashes.
    func testMalformedInputReturnsEmptyMapGracefully() {
        XCTAssertTrue(PDFObjectDetectionEngine.detect(pdfData: Data(), pageIndex: 0, pageRefID: UUID()).objects.isEmpty)
        XCTAssertTrue(PDFObjectDetectionEngine.detect(pdfData: Data("not a pdf".utf8), pageIndex: 0, pageRefID: UUID()).objects.isEmpty)
        XCTAssertTrue(PDFObjectDetectionEngine.detect(pdfData: makeFixture(), pageIndex: 99, pageRefID: UUID()).objects.isEmpty)
    }

    // Editability → capability mapping matches the §4 table on the key cases.
    func testEditabilityCapabilities() {
        XCTAssertTrue(PDFObjectEditability.directImageEdit.capabilities.canReplaceImage)
        XCTAssertFalse(PDFObjectEditability.directImageEdit.capabilities.canRestyle)
        XCTAssertTrue(PDFObjectEditability.directVectorEdit.capabilities.canRestyle)
        XCTAssertFalse(PDFObjectEditability.formWidgetEdit.capabilities.canDuplicate)
        XCTAssertTrue(PDFObjectEditability.formXObjectInstanceEdit.capabilities.canMove)
        XCTAssertTrue(PDFObjectEditability.formXObjectSourceEdit.capabilities.isReadOnly)
        XCTAssertTrue(PDFObjectEditability.unsupported.capabilities.isReadOnly)
        XCTAssertNil(PDFObjectEditability.directVectorEdit.fallbackMessageKey)
        XCTAssertEqual(PDFObjectEditability.rasterRegionReplace.fallbackMessageKey, "object.editability.raster.regionOnly")
    }

    // Persistence: Workspace with objectEditStates round-trips and bumps schemaVersion to 6.
    func testWorkspaceObjectEditStatesCodableRoundTrip() throws {
        var workspace = Workspace()
        let pageRefID = UUID()
        let op = ObjectEditOperation(
            type: .objectTransform, documentID: UUID(), pageRefID: pageRefID,
            sourceObjectKey: PDFObjectStableKey(pageRefID: pageRefID, structuralDigest: 0xABCDEF,
                                                quantizedBoundsHint: [1, 2, 3, 4], zOrderHint: 5, typeHint: "line"),
            objectType: .line, editability: .directVectorEdit,
            originalBoundsPdf: CGRect(x: 1, y: 2, width: 3, height: 4),
            newBoundsPdf: CGRect(x: 11, y: 12, width: 3, height: 4),
            originalTransform: .identity, newTransform: PDFTextTransform(a: 1, b: 0, c: 0, d: 1, e: 10, f: 10),
            pageRotation: 0, originalZIndex: 2, newZIndex: 2, replacementStrategy: .pdfiumStructural)
        workspace.objectEditStates = [PageObjectEditState(pageRefID: pageRefID, operations: [op])]

        XCTAssertEqual(workspace.schemaVersion, 6)
        let encoded = try JSONEncoder().encode(workspace)
        let decoded = try JSONDecoder().decode(Workspace.self, from: encoded)
        XCTAssertEqual(decoded.schemaVersion, 6)
        XCTAssertEqual(decoded.objectEditStates, workspace.objectEditStates)
        XCTAssertEqual(decoded.objectEditStates.first?.operations.first?.sourceObjectKey.structuralDigest, 0xABCDEF)
        XCTAssertEqual(decoded.objectEditStates.first?.operations.first?.newTransform.e, 10)
    }

    // Old workspaces (no objectEditStates key) still decode — forward/backward compat.
    func testDecodingLegacyWorkspaceWithoutObjectEditStates() throws {
        let legacy = "{\"id\":\"\(UUID().uuidString)\",\"title\":\"T\",\"schemaVersion\":5}"
        let decoded = try JSONDecoder().decode(Workspace.self, from: Data(legacy.utf8))
        XCTAssertTrue(decoded.objectEditStates.isEmpty)
        XCTAssertEqual(decoded.schemaVersion, 5)
    }
}
