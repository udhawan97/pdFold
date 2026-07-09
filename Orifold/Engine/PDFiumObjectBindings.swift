import Foundation

// =============================================================================
// PDFium page-object C bindings for the Object Editing System (read + edit surface).
//
// Bound via @_silgen_name with a `poe_` (PDF Object Editing) prefix so the Swift names never
// collide with the file-private bindings already declared in PDFCompressionService /
// PDFTextAnalysisEngine (the alias trick — multiple external declarations of the same C symbol
// are fine at link time). Verified present in the linked framework via `nm`. The library
// lifecycle (FPDF_InitLibrary / LoadMemDocument / CloseDocument / GetPageCount) and `pdfiumLock`
// live in PDFiumProcessingEngine.swift and are reused, not re-declared.
//
// COLOR-PRESERVATION (Phase 0, docs/OBJECT_EDITING_PLAN.md §0.2): FPDFPage_GenerateContent drops
// the fill/stroke color of parsed path objects. Any code that calls GenerateContent MUST first
// "touch" every path's color via poe_GetFillColor→poe_SetFillColor (and the stroke pair).
// =============================================================================

/// FS_MATRIX marshalling struct (fpdfview.h: 6 floats a b c d e f).
struct POEFSMatrix {
    var a: Float = 1, b: Float = 0, c: Float = 0, d: Float = 1, e: Float = 0, f: Float = 0
}

// PDFium page-object type constants (fpdf_edit.h).
enum POEObjType {
    static let text: Int32 = 1
    static let path: Int32 = 2
    static let image: Int32 = 3
    static let shading: Int32 = 4
    static let form: Int32 = 5
}

// Path segment + fill-mode constants (fpdf_edit.h).
enum POESeg {
    static let unknown: Int32 = -1
    static let lineTo: Int32 = 0
    static let bezierTo: Int32 = 1
    static let moveTo: Int32 = 2
}
enum POEFillMode {
    static let none: Int32 = 0
    static let alternate: Int32 = 1
    static let winding: Int32 = 2
}

// MARK: - Page lifecycle & enumeration
@_silgen_name("FPDF_LoadPage") func poe_LoadPage(_ document: OpaquePointer?, _ pageIndex: Int32) -> OpaquePointer?
@_silgen_name("FPDF_ClosePage") func poe_ClosePage(_ page: OpaquePointer?)
@_silgen_name("FPDFPage_GetRotation") func poe_GetPageRotation(_ page: OpaquePointer?) -> Int32
@_silgen_name("FPDFPage_CountObjects") func poe_CountObjects(_ page: OpaquePointer?) -> Int32
@_silgen_name("FPDFPage_GetObject") func poe_GetObject(_ page: OpaquePointer?, _ index: Int32) -> OpaquePointer?
@_silgen_name("FPDF_GetPageWidth") func poe_GetPageWidth(_ page: OpaquePointer?) -> Double
@_silgen_name("FPDF_GetPageHeight") func poe_GetPageHeight(_ page: OpaquePointer?) -> Double

// MARK: - Object type / geometry
@_silgen_name("FPDFPageObj_GetType") func poe_GetType(_ obj: OpaquePointer?) -> Int32
@_silgen_name("FPDFPageObj_GetBounds")
func poe_GetBounds(_ obj: OpaquePointer?, _ l: UnsafeMutablePointer<Float>?, _ b: UnsafeMutablePointer<Float>?, _ r: UnsafeMutablePointer<Float>?, _ t: UnsafeMutablePointer<Float>?) -> Int32
@_silgen_name("FPDFPageObj_GetMatrix") func poe_GetMatrix(_ obj: OpaquePointer?, _ matrix: UnsafeMutablePointer<POEFSMatrix>?) -> Int32
@_silgen_name("FPDFPageObj_SetMatrix") func poe_SetMatrix(_ obj: OpaquePointer?, _ matrix: UnsafePointer<POEFSMatrix>?) -> Int32
@_silgen_name("FPDFPageObj_GetClipPath") func poe_GetClipPath(_ obj: OpaquePointer?) -> OpaquePointer?

// MARK: - Path geometry
@_silgen_name("FPDFPath_CountSegments") func poe_PathCountSegments(_ path: OpaquePointer?) -> Int32
@_silgen_name("FPDFPath_GetPathSegment") func poe_PathGetSegment(_ path: OpaquePointer?, _ index: Int32) -> OpaquePointer?
@_silgen_name("FPDFPathSegment_GetType") func poe_SegGetType(_ segment: OpaquePointer?) -> Int32
@_silgen_name("FPDFPathSegment_GetPoint") func poe_SegGetPoint(_ segment: OpaquePointer?, _ x: UnsafeMutablePointer<Float>?, _ y: UnsafeMutablePointer<Float>?) -> Int32
@_silgen_name("FPDFPathSegment_GetClose") func poe_SegGetClose(_ segment: OpaquePointer?) -> Int32
@_silgen_name("FPDFPath_GetDrawMode") func poe_PathGetDrawMode(_ path: OpaquePointer?, _ fillmode: UnsafeMutablePointer<Int32>?, _ stroke: UnsafeMutablePointer<Int32>?) -> Int32

// MARK: - Style
@_silgen_name("FPDFPageObj_GetFillColor") func poe_GetFillColor(_ obj: OpaquePointer?, _ r: UnsafeMutablePointer<UInt32>?, _ g: UnsafeMutablePointer<UInt32>?, _ b: UnsafeMutablePointer<UInt32>?, _ a: UnsafeMutablePointer<UInt32>?) -> Int32
@_silgen_name("FPDFPageObj_SetFillColor") func poe_SetFillColor(_ obj: OpaquePointer?, _ r: UInt32, _ g: UInt32, _ b: UInt32, _ a: UInt32) -> Int32
@_silgen_name("FPDFPageObj_GetStrokeColor") func poe_GetStrokeColor(_ obj: OpaquePointer?, _ r: UnsafeMutablePointer<UInt32>?, _ g: UnsafeMutablePointer<UInt32>?, _ b: UnsafeMutablePointer<UInt32>?, _ a: UnsafeMutablePointer<UInt32>?) -> Int32
@_silgen_name("FPDFPageObj_SetStrokeColor") func poe_SetStrokeColor(_ obj: OpaquePointer?, _ r: UInt32, _ g: UInt32, _ b: UInt32, _ a: UInt32) -> Int32
@_silgen_name("FPDFPageObj_GetStrokeWidth") func poe_GetStrokeWidth(_ obj: OpaquePointer?, _ width: UnsafeMutablePointer<Float>?) -> Int32

// MARK: - Image
@_silgen_name("FPDFImageObj_GetImagePixelSize") func poe_ImageGetPixelSize(_ obj: OpaquePointer?, _ w: UnsafeMutablePointer<UInt32>?, _ h: UnsafeMutablePointer<UInt32>?) -> Int32

// MARK: - Form XObject
@_silgen_name("FPDFFormObj_CountObjects") func poe_FormCountObjects(_ formObject: OpaquePointer?) -> Int32

// MARK: - Structural edit (used by the write-back engine; declared here so both share one surface)
@_silgen_name("FPDFPage_RemoveObject") func poe_RemoveObject(_ page: OpaquePointer?, _ obj: OpaquePointer?) -> Int32
@_silgen_name("FPDFPageObj_Destroy") func poe_Destroy(_ obj: OpaquePointer?)
@_silgen_name("FPDFPage_InsertObjectAtIndex") func poe_InsertObjectAtIndex(_ page: OpaquePointer?, _ obj: OpaquePointer?, _ index: Int) -> Int32
@_silgen_name("FPDFPageObj_AddMark") func poe_AddMark(_ obj: OpaquePointer?, _ name: UnsafePointer<CChar>?) -> OpaquePointer?
@_silgen_name("FPDFPageObj_CountMarks") func poe_CountMarks(_ obj: OpaquePointer?) -> Int32
@_silgen_name("FPDFPageObj_GetMark") func poe_GetMark(_ obj: OpaquePointer?, _ index: UInt) -> OpaquePointer?
@_silgen_name("FPDFPageObjMark_GetName") func poe_MarkGetName(_ mark: OpaquePointer?, _ buffer: UnsafeMutablePointer<UInt16>?, _ buflen: UInt, _ outBuflen: UnsafeMutablePointer<UInt>?) -> Int32
@_silgen_name("FPDFPage_GenerateContent") func poe_GenerateContent(_ page: OpaquePointer?) -> Int32

// MARK: - Shared helpers

extension POEFSMatrix {
    init(_ t: PDFTextTransform) {
        self.init(a: Float(t.a), b: Float(t.b), c: Float(t.c), d: Float(t.d), e: Float(t.e), f: Float(t.f))
    }
    var textTransform: PDFTextTransform {
        PDFTextTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), e: CGFloat(e), f: CGFloat(f))
    }
}

/// FNV-1a over quantized doubles — the `structuralDigest` primitive (0.01 quantization,
/// sign-folded so it is mirror-stable). Proven translation-invariant in Phase 0.
func poeStructuralDigest(_ values: [Double]) -> UInt64 {
    var h: UInt64 = 0xcbf29ce484222325
    for v in values {
        var q = Int64((v * 100).rounded()).magnitude
        for _ in 0..<8 { h = (h ^ (q & 0xff)) &* 0x100000001b3; q >>= 8 }
    }
    return h
}

/// The MANDATORY Phase-0 color-preservation pass: touch every PATH object's fill+stroke color
/// (Get→Set) so `FPDFPage_GenerateContent` re-emits the color operators it otherwise drops.
/// Call immediately before `poe_GenerateContent` on any page being regenerated.
func poeTouchPathColorsForGenerateContent(_ page: OpaquePointer?) {
    let count = poe_CountObjects(page)
    guard count > 0 else { return }
    for i in 0..<count {
        guard let obj = poe_GetObject(page, i), poe_GetType(obj) == POEObjType.path else { continue }
        var r: UInt32 = 0, g: UInt32 = 0, b: UInt32 = 0, a: UInt32 = 0
        if poe_GetFillColor(obj, &r, &g, &b, &a) != 0 { _ = poe_SetFillColor(obj, r, g, b, a) }
        var sr: UInt32 = 0, sg: UInt32 = 0, sb: UInt32 = 0, sa: UInt32 = 0
        if poe_GetStrokeColor(obj, &sr, &sg, &sb, &sa) != 0 { _ = poe_SetStrokeColor(obj, sr, sg, sb, sa) }
    }
}
