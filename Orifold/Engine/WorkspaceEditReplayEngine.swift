import Foundation
import PDFKit

/// Deterministically rebuilds a member PDF from one canonical base and both committed
/// editing lanes. Object operations are applied structurally first; text replacements
/// then render over that result. The caller supplies workspace-to-member page indexes,
/// while this module owns replay order, annotation preservation, stamps, and serialization.
enum WorkspaceEditReplayEngine {
    struct PageReplay {
        var pageIndex: Int
        var textOperations: [PDFTextEditOperation]
        var objectOperations: [ObjectEditOperation]
    }

    struct Result {
        var data: Data
        var unresolvedObjectOperationIDs: Set<UUID>
    }

    static func replay(baseData: Data, currentData: Data?, pages: [PageReplay]) -> Result? {
        guard !baseData.isEmpty else { return nil }

        var pagesByIndex: [Int: PageReplay] = [:]
        for page in pages {
            guard page.pageIndex >= 0 else { return nil }
            if var existing = pagesByIndex[page.pageIndex] {
                existing.textOperations.append(contentsOf: page.textOperations)
                existing.objectOperations.append(contentsOf: page.objectOperations)
                pagesByIndex[page.pageIndex] = existing
            } else {
                pagesByIndex[page.pageIndex] = page
            }
        }
        let normalizedPages = pagesByIndex.values.sorted { $0.pageIndex < $1.pageIndex }
        let objectOperationsByPage = normalizedPages.reduce(into: [Int: [ObjectEditOperation]]()) { result, page in
            guard !page.objectOperations.isEmpty else { return }
            result[page.pageIndex] = page.objectOperations
        }
        let expectedObjectOperationIDs = Set(objectOperationsByPage.values.flatMap { $0.map(\.id) })
        let objectResult: PDFObjectEditEngine.Result
        if objectOperationsByPage.isEmpty {
            objectResult = PDFObjectEditEngine.Result(data: baseData, appliedOpIDs: [], unresolvedOpIDs: [])
        } else {
            guard let applied = PDFObjectEditEngine.apply(
                operationsByPage: objectOperationsByPage,
                toMember: baseData
            ) else { return nil }
            objectResult = applied
        }

        let reportedObjectOperationIDs = objectResult.appliedOpIDs.union(objectResult.unresolvedOpIDs)
        guard reportedObjectOperationIDs.isSubset(of: expectedObjectOperationIDs),
              objectResult.appliedOpIDs.isDisjoint(with: objectResult.unresolvedOpIDs) else { return nil }
        let unresolvedObjectOperationIDs = objectResult.unresolvedOpIDs.union(
            expectedObjectOperationIDs.subtracting(reportedObjectOperationIDs)
        )

        guard let replayedPDF = PDFDocument(data: objectResult.data) else { return nil }
        let currentPDF = currentData.flatMap(PDFDocument.init(data:))
        var overlays: [PDFPageOverlayMergeEngine.Overlay] = []
        for pageReplay in normalizedPages {
            guard pageReplay.pageIndex >= 0,
                  pageReplay.pageIndex < replayedPDF.pageCount,
                  let objectEditedPage = replayedPDF.page(at: pageReplay.pageIndex) else { return nil }
            guard !pageReplay.textOperations.isEmpty else { continue }
            guard let overlayData = PDFEditedPageRenderer.replacementOverlayData(
                from: objectEditedPage,
                applying: pageReplay.textOperations
            ) else { return nil }
            let mediaBox = objectEditedPage.bounds(for: .mediaBox)
            overlays.append(PDFPageOverlayMergeEngine.Overlay(
                pageIndex: pageReplay.pageIndex,
                data: overlayData,
                originX: mediaBox.minX,
                originY: mediaBox.minY
            ))
        }

        guard let overlaidData = PDFPageOverlayMergeEngine.merge(
            overlays: overlays,
            into: objectResult.data
        ) else { return nil }
        let interactiveData: Data
        if let currentData {
            guard let preserved = QPDFService.replacingInteractiveState(
                in: overlaidData,
                from: currentData
            ) else { return nil }
            interactiveData = preserved
        } else {
            interactiveData = overlaidData
        }
        var rotations: [Int: Int] = [:]
        if let currentPDF {
            for pageIndex in 0..<currentPDF.pageCount {
                rotations[pageIndex] = currentPDF.page(at: pageIndex)?.rotation
            }
        }
        let bakeStamps = pagesByIndex.reduce(into: [Int: String]()) { result, entry in
            result[entry.key] = BakeStamp.hash(
                textOperations: entry.value.textOperations,
                objectOperations: entry.value.objectOperations
            )
        }
        guard let finalized = PDFReplayMetadataEngine.finalize(
            memberData: interactiveData,
            rotations: rotations,
            bakeStamps: bakeStamps
        ) else { return nil }
        return Result(
            data: finalized,
            unresolvedObjectOperationIDs: unresolvedObjectOperationIDs
        )
    }
}
