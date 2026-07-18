import CoreGraphics
import CoreText
import XCTest
@testable import Orifold

/// Covers the procedural hanko renderer (Feature F1): a vermillion border (circle or
/// square) wrapping a vertically stacked column of CJK glyphs, emitted as a `CGPath` for
/// on-canvas drawing and as a self-contained vector PDF appearance stream for export.
/// Glyphs are rendered to outline paths (no embedded font) so a CJK seal never bloats the
/// exported PDF with a subset of a multi-megabyte typeface — the same trick the typed
/// signature renderer uses. All assertions are geometry/byte based (CI-safe).
final class HankoRendererTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 120, height: 120)

    func testOutlinePathBoundsAreDeterministicAndWithinBounds() throws {
        let config = HankoConfig(shape: .circle, text: "確認")
        let first = try HankoRenderer.outlinePath(for: config, in: bounds)
        let second = try HankoRenderer.outlinePath(for: config, in: bounds)

        // Deterministic: identical inputs must yield an identical path bounding box.
        XCTAssertEqual(first.boundingBoxOfPath, second.boundingBoxOfPath)

        let box = first.boundingBoxOfPath
        XCTAssertFalse(box.isNull)
        XCTAssertGreaterThan(box.width, 0)
        XCTAssertGreaterThan(box.height, 0)
        // Border + glyphs stay inside the requested bounds (allow sub-pixel slack).
        XCTAssertTrue(bounds.insetBy(dx: -0.5, dy: -0.5).contains(box),
                      "hanko geometry \(box) escaped its bounds \(bounds)")
    }

    func testGlyphStackAndBorderAreBothPresentWithinBounds() throws {
        // A single-glyph circular seal and a four-glyph square seal should both compose a
        // path that is richer than the border alone (i.e. the glyph column contributes).
        let borderOnly = try HankoRenderer.outlinePath(for: HankoConfig(shape: .circle, text: "印"), in: bounds)
        XCTAssertGreaterThan(elementCount(of: borderOnly), 8, "expected border ring + glyph contours")

        let square = try HankoRenderer.outlinePath(for: HankoConfig(shape: .square, text: "印鑑登録"), in: bounds)
        XCTAssertTrue(bounds.insetBy(dx: -0.5, dy: -0.5).contains(square.boundingBoxOfPath))
        XCTAssertGreaterThan(elementCount(of: square), elementCount(of: borderOnly),
                             "four stacked glyphs should add more path segments than one")
    }

    func testAppearanceStreamIsSelfContainedVector() throws {
        let config = HankoConfig(shape: .circle, text: "承認")
        let stream = try HankoRenderer.pdfAppearanceStream(for: config, bounds: bounds)
        XCTAssertEqual(stream.bbox, CGRect(origin: .zero, size: bounds.size))

        let body = String(decoding: stream.xobject, as: UTF8.self)
        XCTAssertTrue(body.contains(" rg"), "stream must set an RGB fill colour")
        XCTAssertTrue(body.contains("f"), "stream must fill the vector geometry")
        // The whole point of rendering glyphs to paths: no font resource is referenced, so
        // the exported seal can't drag in a subset of a multi-megabyte CJK typeface.
        XCTAssertFalse(body.contains("/F1"), "appearance stream must not reference an external font")
    }

    /// Feature F2: the bundled Shippori Mincho must be present and registered (not silently
    /// falling back to a system face), and carry a genuinely rich outline for a CJK kanji.
    /// `折` (fold) — the character behind the app's own name — is a many-segment mincho glyph.
    func testBundledShipporiMinchoProvidesRichCJKOutline() throws {
        FontRegistrar.registerBundledFonts()
        let font = CTFontCreateWithName("ShipporiMincho-Regular" as CFString, 100, nil)
        XCTAssertEqual(
            CTFontCopyPostScriptName(font) as String, "ShipporiMincho-Regular",
            "Shippori Mincho must be bundled + registered, not resolving to a system fallback"
        )
        let path = try XCTUnwrap(
            CTFontCreatePathForGlyph(font, glyphID(for: "折", in: font), nil),
            "Shippori Mincho must contain a 折 glyph"
        )
        XCTAssertGreaterThan(elementCount(of: path), 12, "expected a rich vector outline for 折")
    }

    func testEmptyTextThrows() {
        XCTAssertThrowsError(
            try HankoRenderer.outlinePath(for: HankoConfig(shape: .square, text: "   "), in: bounds)
        ) { error in
            XCTAssertEqual(error as? HankoError, .emptyText)
        }
    }

    func testNonPositiveBoundsThrowInvalidSize() {
        XCTAssertThrowsError(
            try HankoRenderer.pdfAppearanceStream(for: HankoConfig(shape: .circle, text: "印"), bounds: .zero)
        ) { error in
            XCTAssertEqual(error as? HankoError, .invalidSize)
        }
    }

    private func elementCount(of path: CGPath) -> Int {
        var count = 0
        path.applyWithBlock { _ in count += 1 }
        return count
    }

    private func glyphID(for character: String, in font: CTFont) -> CGGlyph {
        let string = character as NSString
        var characters = [UniChar](repeating: 0, count: string.length)
        string.getCharacters(&characters)
        var glyphs = [CGGlyph](repeating: 0, count: string.length)
        CTFontGetGlyphsForCharacters(font, &characters, &glyphs, string.length)
        return glyphs[0]
    }
}
