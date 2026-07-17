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
        var appliedObjectOperationIDs: Set<UUID>
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

        guard let replayedPDF = PDFDocument(data: objectResult.data) else { return nil }
        let currentPDF = currentData.flatMap(PDFDocument.init(data:))

        for pageReplay in normalizedPages {
            guard pageReplay.pageIndex >= 0,
                  pageReplay.pageIndex < replayedPDF.pageCount,
                  let objectEditedPage = replayedPDF.page(at: pageReplay.pageIndex),
                  let regenerated = PDFEditedPageRenderer.regeneratedPage(
                    from: objectEditedPage,
                    applying: pageReplay.textOperations
                  ) else { return nil }

            replayedPDF.removePage(at: pageReplay.pageIndex)
            replayedPDF.insert(regenerated, at: pageReplay.pageIndex)
        }

        // Member-atomic replay starts from pristine bytes, but annotations and rotations are
        // live page state. Preserve them on EVERY page, including untouched siblings, so an edit
        // on page 1 cannot discard a note/signature on page 2. Bake stamps are replaced only on
        // pages represented in the operation plan.
        for pageIndex in 0..<replayedPDF.pageCount {
            guard let replayedPage = replayedPDF.page(at: pageIndex) else { continue }
            let currentPage = currentPDF?.page(at: pageIndex)
            let annotationSource = currentPage ?? replayedPage
            let preservedAnnotations = annotationSource.annotations.compactMap { annotation -> PDFAnnotation? in
                guard !BakeStamp.isStamp(annotation) else { return nil }
                return annotation.copy() as? PDFAnnotation
            }
            if let currentPage {
                replayedPage.rotation = currentPage.rotation
            }
            for annotation in replayedPage.annotations {
                replayedPage.removeAnnotation(annotation)
            }
            preservedAnnotations.forEach(replayedPage.addAnnotation)
            if let pageReplay = pagesByIndex[pageIndex] {
                BakeStamp.attach(
                    BakeStamp.hash(
                        textOperations: pageReplay.textOperations,
                        objectOperations: pageReplay.objectOperations
                    ),
                    to: replayedPage
                )
            }
        }

        guard let serialized = PDFSerializer.data(from: replayedPDF) else { return nil }
        return Result(
            data: serialized,
            appliedObjectOperationIDs: objectResult.appliedOpIDs,
            unresolvedObjectOperationIDs: objectResult.unresolvedOpIDs
        )
    }
}
