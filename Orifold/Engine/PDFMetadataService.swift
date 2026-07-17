import Foundation
import CQPDF

/// The document-level `/Info` dictionary fields Orifold surfaces for viewing
/// and editing. These map 1:1 to the classic PDF Info keys (`/Title`,
/// `/Author`, `/Subject`, `/Keywords`) -- the XMP metadata stream is a
/// separate concern handled by `QPDFService.sanitized(_:removingMetadata:)`.
///
/// Defaults are required: callers construct `PDFDocumentMetadata()` to mean
/// "no metadata" (all fields absent).
struct PDFDocumentMetadata: Equatable {
    var title: String? = nil
    var author: String? = nil
    var subject: String? = nil
    var keywords: String? = nil
}

/// Reads and writes the PDF `/Info` dictionary via qpdf, reusing
/// `QPDFService`'s open/recover/cleanup and write lifecycle rather than
/// touching the C API's document handle in a second place. qpdf never renders
/// or re-encodes page content, so writing metadata this way preserves the text
/// layer and object graph that a PDFKit re-serialization would destroy.
enum PDFMetadataService {
    enum PDFMetadataError: Error, Equatable {
        /// qpdf could not open the source bytes (corrupt, or encrypted without
        /// the supplied password).
        case cannotOpen
        /// qpdf opened the source but the write pass failed to produce bytes.
        case cannotWrite
        /// The write produced bytes that no longer pass qpdf's structural check.
        case invalidOutput
    }

    /// Reads the four surfaced Info-dict fields. An absent or empty value maps
    /// to `nil`. Throws `.cannotOpen` when qpdf can't parse `data` (including an
    /// encrypted document whose `password` is missing or wrong).
    static func read(from data: Data, password: String? = nil) throws -> PDFDocumentMetadata {
        let metadata = QPDFService.withQPDF(data, description: "metadata-read", password: password) { qpdf -> PDFDocumentMetadata in
            let info = qpdf_oh_get_key(qpdf, qpdf_get_trailer(qpdf), "/Info")
            guard qpdf_oh_is_dictionary(qpdf, info) == QPDF_TRUE else {
                return PDFDocumentMetadata()
            }
            return PDFDocumentMetadata(
                title: infoValue(qpdf, info, "/Title"),
                author: infoValue(qpdf, info, "/Author"),
                subject: infoValue(qpdf, info, "/Subject"),
                keywords: infoValue(qpdf, info, "/Keywords")
            )
        }
        guard let metadata else { throw PDFMetadataError.cannotOpen }
        return metadata
    }

    /// Reads one Info-dict string value as UTF-8. Deliberately *not*
    /// `qpdf_get_info_key`, whose C-string result is the raw, undecoded PDF
    /// string: a Unicode title is stored as UTF-16BE with a `FE FF` BOM, so
    /// `String(cString:)` both misreads the bytes and truncates at the first
    /// embedded NUL. `qpdf_oh_get_value_as_utf8` performs the PDFDoc/UTF-16BE ->
    /// UTF-8 decode and hands back an explicit length, so we copy the exact
    /// bytes immediately (qpdf owns the buffer). Absent, non-string, or empty
    /// values all map to `nil`.
    private static func infoValue(_ qpdf: qpdf_data, _ info: qpdf_oh, _ key: String) -> String? {
        guard qpdf_oh_has_key(qpdf, info, key) == QPDF_TRUE else { return nil }
        let field = qpdf_oh_get_key(qpdf, info, key)
        var raw: UnsafePointer<CChar>?
        var length: Int = 0
        guard qpdf_oh_get_value_as_utf8(qpdf, field, &raw, &length) == QPDF_TRUE,
              let raw, length > 0 else { return nil }
        let value = raw.withMemoryRebound(to: UInt8.self, capacity: length) { bytes in
            String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
        }
        return value.isEmpty ? nil : value
    }
}
