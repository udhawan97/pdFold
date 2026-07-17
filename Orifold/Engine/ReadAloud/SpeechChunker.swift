import Foundation
import NaturalLanguage

/// One spoken unit of read-aloud: a single sentence, tagged with the page it came from
/// and its location within that page's text as a UTF-16 `NSRange`.
///
/// The range is UTF-16 (not `Range<String.Index>`) on purpose — `PDFPage.selection(for:)`,
/// which the follow-along highlight bridge feeds it into, expects UTF-16 offsets. Storing
/// `text` as the exact substring the range points at lets the bridge round-trip
/// range → substring without drift, including across emoji/CJK where UTF-16 and grapheme
/// counts diverge.
struct SpeechChunk: Equatable {
    let text: String
    let pageIndex: Int
    let rangeInPage: NSRange
}

/// Splits a page's plain text into sentence-granular `SpeechChunk`s for read-aloud.
///
/// Sentence segmentation uses `NLTokenizer(unit: .sentence)` from NaturalLanguage —
/// available since macOS 14 (the app's minimum) and script-aware, so it handles CJK text
/// that carries no ASCII whitespace between sentences.
enum SpeechChunker {
    static func chunks(forPageText text: String, pageIndex: Int) -> [SpeechChunk] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var chunks: [SpeechChunk] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            // Skip tokens that are only whitespace/newlines — the synthesizer has nothing
            // to say for them, and they'd produce empty highlights.
            guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return true
            }
            chunks.append(
                SpeechChunk(
                    text: sentence,
                    pageIndex: pageIndex,
                    // `NSRange(_:in:)` converts the `Range<String.Index>` into UTF-16 offsets
                    // against the same `text`, so `(text as NSString).substring(with:)` returns
                    // exactly `sentence`.
                    rangeInPage: NSRange(range, in: text)
                )
            )
            return true
        }
        return chunks
    }
}
