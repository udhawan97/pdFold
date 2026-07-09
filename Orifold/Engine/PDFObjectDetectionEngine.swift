import Foundation
import CoreGraphics

// =============================================================================
// PDFObjectDetectionEngine — the per-page PDFium page-object enumeration + classification pass
// (docs/OBJECT_EDITING_PLAN.md §2). Produces a read-only PageObjectMap for hit-testing/selection;
// it never mutates bytes. Runs under `pdfiumLock` against PRISTINE member bytes and never throws
// (returns an empty map on any failure — Test #29 malformed/graceful-degradation).
//
// Phase-1 scope: PDFium content-stream objects (image / vector path→line/rect/ellipse/shape /
// Form XObject instance / shading). TEXT objects are intentionally skipped — they belong to the
// inline text-edit lane (§7). PDFKit annotations/widgets and Tier-B table clustering (§2.2) layer
// on later; the model already carries the fields for them.
// =============================================================================

struct PDFObjectDetectionEngine {

    /// Safety cap mirroring PageGraphicsIndex — beyond it the map is marked `didTruncateScan`.
    static let maxObjectsScan = 4000

    /// Detect page objects on `pageIndex` of pristine member `pdfData`. `allowsEditing == false`
    /// (permission-restricted / signed) forces every object to `lockedOrPermissionRestricted`.
    static func detect(pdfData: Data, pageIndex: Int, pageRefID: UUID,
                       allowsEditing: Bool = true) -> PageObjectMap {
        guard !pdfData.isEmpty, pdfData.count <= Int(Int32.max) else {
            return PageObjectMap(pageRefID: pageRefID, objects: [])
        }
        pdfiumLock.lock()
        defer { pdfiumLock.unlock() }
        FPDF_InitLibrary()
        defer { FPDF_DestroyLibrary() }

        return pdfData.withUnsafeBytes { raw -> PageObjectMap in
            guard let base = raw.baseAddress,
                  let doc = FPDF_LoadMemDocument(base, Int32(pdfData.count), nil) else {
                return PageObjectMap(pageRefID: pageRefID, objects: [])
            }
            defer { FPDF_CloseDocument(doc) }
            guard pageIndex >= 0, pageIndex < Int(FPDF_GetPageCount(doc)),
                  let page = poe_LoadPage(doc, Int32(pageIndex)) else {
                return PageObjectMap(pageRefID: pageRefID, objects: [])
            }
            defer { poe_ClosePage(page) }

            let pageRotation = CGFloat(((poe_GetPageRotation(page) % 4) + 4) % 4) * 90
            let pageArea = max(1, poe_GetPageWidth(page) * poe_GetPageHeight(page))
            let rawCount = Int(poe_CountObjects(page))
            let truncated = rawCount > maxObjectsScan
            let count = min(rawCount, maxObjectsScan)

            var objects: [DetectedObject] = []
            objects.reserveCapacity(count)
            for i in 0..<count {
                guard let obj = poe_GetObject(page, Int32(i)) else { continue }
                let type = poe_GetType(obj)
                guard type != POEObjType.text else { continue }   // text belongs to the text lane
                if let detected = build(obj: obj, zOrder: i, type: type, pageRefID: pageRefID,
                                        pageRotation: pageRotation, pageArea: pageArea,
                                        allowsEditing: allowsEditing) {
                    objects.append(detected)
                }
            }
            return PageObjectMap(pageRefID: pageRefID, objects: objects, didTruncateScan: truncated)
        }
    }

    // MARK: - Per-object build

    private static func build(obj: OpaquePointer?, zOrder: Int, type: Int32, pageRefID: UUID,
                              pageRotation: CGFloat, pageArea: Double, allowsEditing: Bool) -> DetectedObject? {
        var l: Float = 0, b: Float = 0, r: Float = 0, t: Float = 0
        guard poe_GetBounds(obj, &l, &b, &r, &t) != 0 else { return nil }
        let bounds = CGRect(x: CGFloat(min(l, r)), y: CGFloat(min(b, t)),
                            width: CGFloat(abs(r - l)), height: CGFloat(abs(t - b)))
        guard bounds.width.isFinite, bounds.height.isFinite else { return nil }

        var m = POEFSMatrix()
        _ = poe_GetMatrix(obj, &m)
        let transform = m.textTransform

        var clip = PDFObjectClipInfo()
        if poe_GetClipPath(obj) != nil { clip.hasClip = true }

        let areaFraction = Double(bounds.width * bounds.height) / pageArea
        let isBackgroundLike = areaFraction >= 0.92

        var style = PDFObjectStyle()
        var pathData: PDFPathData?
        var imageMeta: PDFObjectImageMetadata?
        var formName: String?
        var childCount = 0

        var objectType: PDFObjectType
        var confidence: PDFTextEditConfidence
        var digestValues: [Double]

        switch type {
        case POEObjType.image:
            objectType = .imageXObject
            confidence = .high
            var pw: UInt32 = 0, ph: UInt32 = 0
            _ = poe_ImageGetPixelSize(obj, &pw, &ph)
            imageMeta = PDFObjectImageMetadata(pixelWidth: Int(pw), pixelHeight: Int(ph), hasSoftMask: clip.hasSoftMask)
            style.opacity = 1
            // Intrinsic = source pixel dims (invariant to move AND resize).
            digestValues = [Double(pw), Double(ph)]

        case POEObjType.form:
            objectType = .formXObject
            confidence = .high
            childCount = Int(poe_FormCountObjects(obj))
            formName = nil   // source name not exposed via the declared surface in Phase 1
            digestValues = [Double(childCount), Double(round(bounds.width)), Double(round(bounds.height))]

        case POEObjType.shading:
            objectType = .shading
            confidence = .medium
            digestValues = [Double(round(bounds.width)), Double(round(bounds.height))]

        case POEObjType.path:
            let extracted = extractPath(obj)
            pathData = extracted.data
            style = extracted.style
            (objectType, confidence) = classifyPath(extracted, isBackgroundLike: isBackgroundLike)
            // Intrinsic = segment topology in the path's own (matrix-independent) space.
            digestValues = extracted.data.segments.flatMap { [Double($0.kind.ordinal), Double($0.point.x), Double($0.point.y)] }
            if digestValues.isEmpty { digestValues = [Double(round(bounds.width)), Double(round(bounds.height))] }

        default:
            objectType = .vectorPath
            confidence = .low
            digestValues = [Double(round(bounds.width)), Double(round(bounds.height))]
        }

        let digest = poeStructuralDigest(digestValues + [Double(objectType.hashDiscriminator)])
        let stableKey = PDFObjectStableKey(
            pageRefID: pageRefID,
            structuralDigest: digest,
            quantizedBoundsHint: [Int(round(bounds.minX)), Int(round(bounds.minY)),
                                  Int(round(bounds.width)), Int(round(bounds.height))],
            zOrderHint: zOrder,
            typeHint: objectType.rawValue,
            sourceXObjectName: formName)

        let editability = classifyEditability(objectType: objectType, confidence: confidence,
                                              clip: clip, isBackgroundLike: isBackgroundLike,
                                              allowsEditing: allowsEditing)

        return DetectedObject(
            stableKey: stableKey, pageRefID: pageRefID, objectType: objectType,
            sourceType: .pdfiumPageObject, confidence: confidence, editability: editability,
            boundsPdf: bounds, transform: transform, pageRotation: pageRotation, zOrder: zOrder,
            style: style, pathData: pathData, imageMetadata: imageMeta, clipInfo: clip,
            groupSource: objectType == .formXObject && childCount > 0 ? .formXObject(name: formName ?? "") : .none,
            formXObjectName: formName, isBackgroundLike: isBackgroundLike)
    }

    // MARK: - Path extraction & classification

    private struct ExtractedPath {
        var data: PDFPathData
        var style: PDFObjectStyle
        var moveCount = 0
        var lineCount = 0
        var bezierCount = 0
        var isClosed = false
    }

    private static func extractPath(_ obj: OpaquePointer?) -> ExtractedPath {
        var fillMode: Int32 = 0, stroke: Int32 = 0
        _ = poe_PathGetDrawMode(obj, &fillMode, &stroke)
        let isFilled = fillMode != POEFillMode.none
        let isStroked = stroke != 0

        var style = PDFObjectStyle()
        style.fillColor = readColor { poe_GetFillColor(obj, $0, $1, $2, $3) }
        style.strokeColor = readColor { poe_GetStrokeColor(obj, $0, $1, $2, $3) }
        var width: Float = 0
        if poe_GetStrokeWidth(obj, &width) != 0 { style.lineWidth = CGFloat(width) }
        style.opacity = style.fillColor?.alpha ?? style.strokeColor?.alpha ?? 1

        var segments: [PDFPathSegment] = []
        var flattened: [CGPoint] = []
        var moveCount = 0, lineCount = 0, bezierCount = 0, closed = false
        let segCount = poe_PathCountSegments(obj)
        if segCount > 0 {
            for i in 0..<segCount {
                guard let seg = poe_PathGetSegment(obj, i) else { continue }
                var x: Float = 0, y: Float = 0
                _ = poe_SegGetPoint(seg, &x, &y)
                let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                let segClosed = poe_SegGetClose(seg) != 0
                if segClosed { closed = true }
                let kind: PDFPathSegmentKind
                switch poe_SegGetType(seg) {
                case POESeg.moveTo: kind = .moveTo; moveCount += 1
                case POESeg.lineTo: kind = .lineTo; lineCount += 1
                case POESeg.bezierTo: kind = .bezierTo; bezierCount += 1
                default: kind = .lineTo; lineCount += 1
                }
                segments.append(PDFPathSegment(kind: kind, point: point, isClosed: segClosed))
                flattened.append(point)   // Phase-1 flatten: on-/control-point polyline (conservative)
            }
        }
        let data = PDFPathData(segments: segments, fillRule: Int(fillMode),
                               isStroked: isStroked, isFilled: isFilled, flattenedStroke: flattened)
        return ExtractedPath(data: data, style: style, moveCount: moveCount,
                             lineCount: lineCount, bezierCount: bezierCount, isClosed: closed)
    }

    private static func classifyPath(_ p: ExtractedPath, isBackgroundLike: Bool)
        -> (PDFObjectType, PDFTextEditConfidence) {
        if isBackgroundLike { return (.filledShape, .low) }   // full-bleed → not default-selectable
        // Line: one move + one line, open, stroked.
        if p.moveCount == 1, p.lineCount == 1, p.bezierCount == 0, !p.isClosed {
            return (.line, .high)
        }
        // Rectangle: closed, no beziers, 3–4 line segments (Quartz emits rect as move+3 line+close).
        if p.isClosed, p.bezierCount == 0, (3...5).contains(p.lineCount) {
            return (.rectangle, .high)
        }
        // Ellipse: closed, ≥4 beziers, few/no straight edges.
        if p.isClosed, p.bezierCount >= 4, p.lineCount <= 1 {
            return (.ellipse, .medium)
        }
        if p.data.isFilled { return (.filledShape, .medium) }
        if p.data.isStroked { return (.strokedShape, .medium) }
        return (.vectorPath, .medium)
    }

    // MARK: - Editability

    private static func classifyEditability(objectType: PDFObjectType, confidence: PDFTextEditConfidence,
                                            clip: PDFObjectClipInfo, isBackgroundLike: Bool,
                                            allowsEditing: Bool) -> PDFObjectEditability {
        guard allowsEditing else { return .lockedOrPermissionRestricted }
        switch objectType {
        case .imageXObject, .flattenedRaster:
            // A soft-masked image can't be structurally replaced cleanly → raster fallback (§10).
            return clip.hasSoftMask ? .rasterRegionReplace : .directImageEdit
        case .line, .rectangle, .ellipse, .filledShape, .strokedShape, .vectorPath:
            // Clipped vectors stay movable (§10 "move preserves the clip") but low-confidence
            // full-bleed artifacts are surfaced as inferred artifacts (not default-selectable).
            if isBackgroundLike || confidence == .low { return .inferredArtifactEdit }
            return .directVectorEdit
        case .decorativeArtifact:
            return .inferredArtifactEdit
        case .tableGrid:
            return .groupedObjectEdit
        case .formXObject:
            return .formXObjectInstanceEdit
        case .formWidget:
            return .formWidgetEdit
        case .annotation:
            return .directAnnotationEdit
        case .shading:
            return .unsupported
        }
    }

    // MARK: - Small helpers

    private static func readColor(_ get: (UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>?) -> Int32) -> CodableColor? {
        var r: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0, a: UInt32 = 0
        guard get(&r, &g, &b, &a) != 0 else { return nil }
        return CodableColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}

private extension PDFPathSegmentKind {
    var ordinal: Int { switch self { case .moveTo: return 0; case .lineTo: return 1; case .bezierTo: return 2; case .close: return 3 } }
}

private extension PDFObjectType {
    /// Small stable per-type discriminator folded into the structural digest so a line and an
    /// image that happen to share a numeric footprint never collide.
    var hashDiscriminator: Int {
        switch self {
        case .annotation: return 1
        case .imageXObject: return 2
        case .vectorPath: return 3
        case .line: return 4
        case .rectangle: return 5
        case .ellipse: return 6
        case .filledShape: return 7
        case .strokedShape: return 8
        case .tableGrid: return 9
        case .formWidget: return 10
        case .formXObject: return 11
        case .shading: return 12
        case .decorativeArtifact: return 13
        case .flattenedRaster: return 14
        }
    }
}
