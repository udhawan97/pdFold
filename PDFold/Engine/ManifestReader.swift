import CoreGraphics
import Foundation

/// Reads a `pdfold-manifest.json` embedded file attachment from a PDF
/// using CoreGraphics — the only free API that can traverse PDF name trees.
enum ManifestReader {

    static func read(from url: URL) -> PDFoldManifest? {
        guard let doc = CGPDFDocument(url as CFURL) else { return nil }
        return read(from: doc)
    }

    static func read(from data: Data) -> PDFoldManifest? {
        guard let provider = CGDataProvider(data: data as CFData),
              let doc = CGPDFDocument(provider) else { return nil }
        return read(from: doc)
    }

    // MARK: - Fallback reader (applies spec §5.2 fallbacks)

    /// Attempts to read the manifest. Returns nil when the file has no
    /// manifest — callers should treat nil as "single document" per spec.
    static func read(from doc: CGPDFDocument) -> PDFoldManifest? {
        guard let catalog = doc.catalog else { return nil }

        var namesPtr: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(catalog, "Names", &namesPtr),
              let names = namesPtr else { return nil }

        var efDictPtr: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(names, "EmbeddedFiles", &efDictPtr),
              let efDict = efDictPtr else { return nil }

        // EmbeddedFiles may be a name tree node or a flat Names array
        var arrPtr: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(efDict, "Names", &arrPtr),
              let arr = arrPtr else { return nil }

        let count = CGPDFArrayGetCount(arr)
        var i = 0
        while i + 1 < count {
            let key = pdfArrayString(arr, at: i) ?? ""
            if key == "pdfold-manifest.json" {
                var fsPtr: CGPDFDictionaryRef?
                if CGPDFArrayGetDictionary(arr, i + 1, &fsPtr), let fs = fsPtr {
                    if let data = extractStreamData(filespec: fs),
                       let manifest = try? JSONDecoder().decode(PDFoldManifest.self, from: data) {
                        return manifest
                    }
                }
            }
            i += 2
        }
        return nil
    }

    // MARK: - Helpers

    private static func pdfArrayString(_ arr: CGPDFArrayRef, at i: Int) -> String? {
        var strRef: CGPDFStringRef?
        if CGPDFArrayGetString(arr, i, &strRef), let s = strRef {
            return CGPDFStringCopyTextString(s) as String?
        }
        var namePtr: UnsafePointer<Int8>?
        if CGPDFArrayGetName(arr, i, &namePtr), let n = namePtr {
            return String(cString: n)
        }
        return nil
    }

    private static func extractStreamData(filespec: CGPDFDictionaryRef) -> Data? {
        var efPtr: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(filespec, "EF", &efPtr), let ef = efPtr else { return nil }
        var streamPtr: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(ef, "F", &streamPtr), let stream = streamPtr else { return nil }
        var fmt = CGPDFDataFormat.raw
        return CGPDFStreamCopyData(stream, &fmt) as Data?
    }
}
