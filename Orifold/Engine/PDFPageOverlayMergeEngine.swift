import Foundation

/// Adds transparent text-edit overlays to already-structurally-edited PDFium pages and writes
/// the member with `SaveAsCopy`. Original page objects remain page objects: this seam never
/// redraws, copies, replaces, or serializes a destination page through PDFKit.
enum PDFPageOverlayMergeEngine {
    struct Overlay {
        var pageIndex: Int
        var data: Data
        /// Translation from the overlay's zero-origin media box into the destination page's
        /// actual media-box origin.
        var originX: CGFloat
        var originY: CGFloat
    }

    static func merge(overlays: [Overlay], into memberData: Data) -> Data? {
        guard !memberData.isEmpty, memberData.count <= Int(Int32.max) else { return nil }
        let nonempty = overlays.filter { !$0.data.isEmpty }
        guard !nonempty.isEmpty else { return memberData }

        pdfiumLock.lock()
        defer { pdfiumLock.unlock() }
        FPDF_InitLibrary()
        defer { FPDF_DestroyLibrary() }

        return memberData.withUnsafeBytes { memberRaw -> Data? in
            guard let memberBase = memberRaw.baseAddress,
                  let destination = FPDF_LoadMemDocument(memberBase, Int32(memberData.count), nil) else { return nil }
            defer { FPDF_CloseDocument(destination) }
            let pageCount = Int(FPDF_GetPageCount(destination))

            for overlay in nonempty {
                guard overlay.pageIndex >= 0, overlay.pageIndex < pageCount,
                      overlay.data.count <= Int(Int32.max) else { return nil }
                let merged = overlay.data.withUnsafeBytes { overlayRaw -> Bool in
                    guard let overlayBase = overlayRaw.baseAddress,
                          let source = FPDF_LoadMemDocument(overlayBase, Int32(overlay.data.count), nil) else { return false }
                    defer { FPDF_CloseDocument(source) }
                    guard FPDF_GetPageCount(source) == 1,
                          let page = poe_LoadPage(destination, Int32(overlay.pageIndex)),
                          let xObject = poe_NewXObjectFromPage(destination, source, 0) else { return false }
                    defer {
                        poe_CloseXObject(xObject)
                        poe_ClosePage(page)
                    }
                    guard let form = poe_NewFormObjectFromXObject(xObject) else { return false }
                    if overlay.originX != 0 || overlay.originY != 0 {
                        var translation = POEFSMatrix(e: Float(overlay.originX), f: Float(overlay.originY))
                        guard poe_SetMatrix(form, &translation) != 0 else {
                            poe_Destroy(form)
                            return false
                        }
                    }
                    guard poe_InsertObjectAtIndex(page, form, Int(poe_CountObjects(page))) != 0 else {
                        // InsertObject owns and frees `form` on failure.
                        return false
                    }
                    poeTouchPathColorsForGenerateContent(page)
                    return poe_GenerateContent(page) != 0
                }
                guard merged else { return nil }
            }

            let saved = PDFObjectEditEngine.saveAsCopy(destination)
            return saved.isEmpty ? nil : saved
        }
    }
}
