import CoreGraphics
import Foundation

/// One bounded PDFium page-object enumeration with typed projections for every read consumer.
/// Text analysis consumes render modes and rule graphics; object editing consumes the object
/// map. Keeping the loop and safety policy here prevents each feature from rescanning the page.
enum PDFPageObjectInspection {
    static let maxObjectsScan = 6000

    struct RenderModeRegion: Equatable {
        var bounds: CGRect
        var mode: Int32
    }

    struct Result {
        var renderModeRegions: [RenderModeRegion]
        var graphics: PageGraphicsIndex
        var objectMap: PageObjectMap
        var rawObjectCount: Int
        var enumeratedObjectCount: Int
    }

    static func inspect(
        pdfData: Data,
        pageIndex: Int,
        pageRefID: UUID,
        allowsEditing: Bool = true
    ) -> Result {
        let empty = Result(
            renderModeRegions: [],
            graphics: .empty,
            objectMap: PageObjectMap(pageRefID: pageRefID, objects: []),
            rawObjectCount: 0,
            enumeratedObjectCount: 0
        )
        guard !pdfData.isEmpty, pdfData.count <= Int(Int32.max) else { return empty }

        pdfiumLock.lock()
        defer { pdfiumLock.unlock() }
        FPDF_InitLibrary()
        defer { FPDF_DestroyLibrary() }

        return pdfData.withUnsafeBytes { raw in
            guard let base = raw.baseAddress,
                  let document = FPDF_LoadMemDocument(base, Int32(pdfData.count), nil) else { return empty }
            defer { FPDF_CloseDocument(document) }
            guard pageIndex >= 0, pageIndex < Int(FPDF_GetPageCount(document)),
                  let page = poe_LoadPage(document, Int32(pageIndex)) else { return empty }
            defer { poe_ClosePage(page) }
            return inspect(openPage: page, pageRefID: pageRefID, allowsEditing: allowsEditing)
        }
    }

    /// Inspects a page already opened inside the caller's PDFium lock/library lifetime.
    static func inspect(
        openPage page: OpaquePointer?,
        pageRefID: UUID,
        allowsEditing: Bool = true
    ) -> Result {
        let rawCount = max(0, Int(poe_CountObjects(page)))
        let scanCount = min(rawCount, maxObjectsScan)
        let objectMapLimit = min(scanCount, PDFObjectDetectionEngine.maxObjectsScan)
        let pageRotation = CGFloat(((poe_GetPageRotation(page) % 4) + 4) % 4) * 90
        let pageArea = max(1, poe_GetPageWidth(page) * poe_GetPageHeight(page))

        var renderModeRegions: [RenderModeRegion] = []
        var graphics = PageGraphicsIndex()
        var objects: [DetectedObject] = []
        renderModeRegions.reserveCapacity(scanCount)
        objects.reserveCapacity(objectMapLimit)

        if rawCount > maxObjectsScan {
            graphics.didTruncateScan = true
            NSLog(
                "[Orifold] PDFPageObjectInspection: page has %d objects, scanning first %d.",
                rawCount,
                maxObjectsScan
            )
        }

        for objectIndex in 0..<scanCount {
            guard let object = poe_GetObject(page, Int32(objectIndex)) else { continue }
            let type = poe_GetType(object)
            if type == POEObjType.text {
                if let bounds = bounds(of: object), bounds.width > 0, bounds.height > 0 {
                    renderModeRegions.append(RenderModeRegion(
                        bounds: bounds,
                        mode: poe_GetTextRenderMode(object)
                    ))
                }
                continue
            }

            if objectIndex < objectMapLimit,
               let detected = PDFObjectDetectionEngine.build(
                obj: object,
                zOrder: objectIndex,
                type: type,
                pageRefID: pageRefID,
                pageRotation: pageRotation,
                pageArea: pageArea,
                allowsEditing: allowsEditing
               ) {
                objects.append(detected)
                if type == POEObjType.path,
                   let rule = PageGraphicsIndex.classify(bounds: detected.boundsPdf) {
                    graphics.add(rule)
                }
            } else if type == POEObjType.path,
                      let objectBounds = bounds(of: object),
                      let rule = PageGraphicsIndex.classify(bounds: objectBounds) {
                graphics.add(rule)
            }
        }

        let objectMap = PageObjectMap(
            pageRefID: pageRefID,
            objects: objects,
            didTruncateScan: rawCount > PDFObjectDetectionEngine.maxObjectsScan,
            rawObjectCount: rawCount
        )
        return Result(
            renderModeRegions: renderModeRegions,
            graphics: graphics,
            objectMap: objectMap,
            rawObjectCount: rawCount,
            enumeratedObjectCount: scanCount
        )
    }

    private static func bounds(of object: OpaquePointer?) -> CGRect? {
        var left: Float = 0
        var bottom: Float = 0
        var right: Float = 0
        var top: Float = 0
        guard poe_GetBounds(object, &left, &bottom, &right, &top) != 0,
              left.isFinite, bottom.isFinite, right.isFinite, top.isFinite else { return nil }
        return CGRect(
            x: CGFloat(min(left, right)),
            y: CGFloat(min(bottom, top)),
            width: CGFloat(abs(right - left)),
            height: CGFloat(abs(top - bottom))
        )
    }
}
