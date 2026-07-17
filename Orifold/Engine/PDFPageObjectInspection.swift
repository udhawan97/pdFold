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
        /// True when cache admission refused the page to preserve its hard memory ceilings.
        /// Consumers must fail closed rather than treating missing safety projections as proof
        /// that content is editable.
        var wasRefused = false
    }

    /// Caller-owned member revision token. A workspace creates one token for canonical member
    /// bytes, reuses it across every page, and explicitly invalidates it only when those canonical
    /// bytes change. This avoids hashing an entire large member on every page lookup.
    struct Revision: Hashable {
        fileprivate let id = UUID()
    }

    /// Snapshot cache shared by text and object consumers. It retains every admitted PageRef for
    /// a member revision until that revision is explicitly invalidated. Explicit page/projection
    /// budgets fail closed for later pages instead of evicting snapshots and silently rescanning.
    final class Cache {
        typealias Inspector = (Data, Int, UUID, Bool) -> Result

        static let defaultMaxRetainedPages = 512
        static let defaultMaxRetainedProjectionUnits = 250_000
        static let defaultMaxTotalRetainedPages = 1_024
        static let defaultMaxTotalRetainedProjectionUnits = 500_000

        private struct Key: Hashable {
            var revision: Revision
            var pageIndex: Int
            var pageRefID: UUID
        }

        private let inspector: Inspector
        private let maxRetainedPages: Int
        private let maxRetainedProjectionUnits: Int
        private let maxTotalRetainedPages: Int
        private let maxTotalRetainedProjectionUnits: Int
        private let lock = NSLock()
        private var results: [Key: Result] = [:]
        private var retainedProjectionUnitsByRevision: [Revision: Int] = [:]
        private var totalRetainedProjectionUnits = 0
        private var saturatedRevisions = Set<Revision>()
        /// Revisions refused only because another revision currently owns global capacity.
        /// They are retryable after any removal; unlike accepted results, no scan is evicted.
        private var globallyRefusedRevisions = Set<Revision>()

        init(
            maxRetainedPages: Int = defaultMaxRetainedPages,
            maxRetainedProjectionUnits: Int = defaultMaxRetainedProjectionUnits,
            maxTotalRetainedPages: Int = defaultMaxTotalRetainedPages,
            maxTotalRetainedProjectionUnits: Int = defaultMaxTotalRetainedProjectionUnits,
            inspector: @escaping Inspector = { data, index, refID, allowsEditing in
                PDFPageObjectInspection.inspect(
                    pdfData: data,
                    pageIndex: index,
                    pageRefID: refID,
                    allowsEditing: allowsEditing
                )
            }
        ) {
            precondition(
                maxRetainedPages > 0 && maxRetainedProjectionUnits > 0
                    && maxTotalRetainedPages > 0 && maxTotalRetainedProjectionUnits > 0
            )
            self.maxRetainedPages = maxRetainedPages
            self.maxRetainedProjectionUnits = maxRetainedProjectionUnits
            self.maxTotalRetainedPages = maxTotalRetainedPages
            self.maxTotalRetainedProjectionUnits = maxTotalRetainedProjectionUnits
            self.inspector = inspector
        }

        func result(
            pdfData: Data,
            pageIndex: Int,
            pageRefID: UUID,
            revision: Revision
        ) -> Result {
            let key = Key(
                revision: revision,
                pageIndex: pageIndex,
                pageRefID: pageRefID
            )
            lock.lock()
            defer { lock.unlock() }
            if let cached = results[key] {
                return cached
            }
            guard !globallyRefusedRevisions.contains(revision) else {
                return limitedResult(pageRefID: pageRefID)
            }
            let retainedPageCount = results.keys.lazy.filter { $0.revision == revision }.count
            guard !saturatedRevisions.contains(revision), retainedPageCount < maxRetainedPages else {
                saturatedRevisions.insert(revision)
                return limitedResult(pageRefID: pageRefID)
            }
            guard results.count < maxTotalRetainedPages else {
                globallyRefusedRevisions.insert(revision)
                return limitedResult(pageRefID: pageRefID)
            }
            // Permission state is a cheap projection over the object map and must not create a
            // second physical scan of identical member bytes.
            let inspected = inspector(pdfData, pageIndex, pageRefID, true)
            let cost = projectionCost(of: inspected)
            let retainedProjectionUnits = retainedProjectionUnitsByRevision[revision, default: 0]
            guard retainedProjectionUnits + cost <= maxRetainedProjectionUnits else {
                let limited = limitedResult(
                    pageRefID: pageRefID,
                    rawObjectCount: inspected.rawObjectCount,
                    enumeratedObjectCount: inspected.enumeratedObjectCount
                )
                results[key] = limited
                saturatedRevisions.insert(revision)
                return limited
            }
            guard totalRetainedProjectionUnits + cost <= maxTotalRetainedProjectionUnits else {
                if cost > maxTotalRetainedProjectionUnits {
                    let limited = limitedResult(
                        pageRefID: pageRefID,
                        rawObjectCount: inspected.rawObjectCount,
                        enumeratedObjectCount: inspected.enumeratedObjectCount
                    )
                    results[key] = limited
                    saturatedRevisions.insert(revision)
                    return limited
                }
                globallyRefusedRevisions.insert(revision)
                return limitedResult(
                    pageRefID: pageRefID,
                    rawObjectCount: inspected.rawObjectCount,
                    enumeratedObjectCount: inspected.enumeratedObjectCount
                )
            }
            results[key] = inspected
            retainedProjectionUnitsByRevision[revision] = retainedProjectionUnits + cost
            totalRetainedProjectionUnits += cost
            return inspected
        }

        func remove(revision: Revision) {
            lock.lock()
            let removedKeys = results.keys.filter { $0.revision == revision }
            for key in removedKeys {
                if let removed = results.removeValue(forKey: key) {
                    totalRetainedProjectionUnits -= projectionCost(of: removed)
                }
            }
            retainedProjectionUnitsByRevision.removeValue(forKey: revision)
            saturatedRevisions.remove(revision)
            globallyRefusedRevisions.remove(revision)
            if !removedKeys.isEmpty {
                // Only releasing an admitted result changes global capacity. Invalidating some
                // other refused revision must not make every waiter repeat a doomed inspection.
                globallyRefusedRevisions.removeAll()
            }
            lock.unlock()
        }

        func removeAll() {
            lock.lock()
            results.removeAll()
            retainedProjectionUnitsByRevision.removeAll()
            totalRetainedProjectionUnits = 0
            saturatedRevisions.removeAll()
            globallyRefusedRevisions.removeAll()
            lock.unlock()
        }

        private func projectionCost(of result: Result) -> Int {
            result.renderModeRegions.count
                + result.graphics.horizontalRules.count
                + result.graphics.verticalRules.count
                + result.objectMap.objects.count
        }

        private func limitedResult(
            pageRefID: UUID,
            rawObjectCount: Int = 0,
            enumeratedObjectCount: Int = 0
        ) -> Result {
            var graphics = PageGraphicsIndex.empty
            graphics.didTruncateScan = true
            return Result(
                renderModeRegions: [],
                graphics: graphics,
                objectMap: PageObjectMap(
                    pageRefID: pageRefID,
                    objects: [],
                    didTruncateScan: true,
                    rawObjectCount: rawObjectCount
                ),
                rawObjectCount: rawObjectCount,
                enumeratedObjectCount: enumeratedObjectCount,
                wasRefused: true
            )
        }
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
