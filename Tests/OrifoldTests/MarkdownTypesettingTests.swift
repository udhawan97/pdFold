import AppKit
import XCTest
@testable import Orifold

/// Regression guard for the markdown import typesetting fix.
///
/// `AttributedString(markdown:, .full)` records block structure as `PresentationIntent`
/// and drops the literal newlines between blocks; bridging straight to `NSAttributedString`
/// then collapses every block into one run — fusing adjacent paragraphs' words with no
/// separator and rendering headings at body size. `typesetMarkdown` re-inserts block breaks
/// and assigns fonts. These tests assert on the laid-out `NSAttributedString` directly so
/// the fix can't silently regress (and so they don't depend on flaky PDF text re-extraction).
final class MarkdownTypesettingTests: XCTestCase {
    private func typeset(_ markdown: String) throws -> NSAttributedString {
        try XCTUnwrap(DocumentImportConverter.markdownAttributedString(from: markdown, baseURL: nil))
    }

    func testAdjacentParagraphsDoNotFuse() throws {
        let ns = try typeset("First paragraph ends here.\n\nSecond paragraph starts here.")
        // The collapse bug produced "here.Second" (word boundary lost). A break must survive.
        XCTAssertFalse(ns.string.contains("here.Second"), "adjacent paragraphs fused with no separator")
        XCTAssertTrue(ns.string.contains("here.\nSecond"), "expected a newline between paragraphs")
    }

    func testHeadingRendersLargerAndBoldThanBody() throws {
        let ns = try typeset("# Big Heading\n\nBody paragraph text.")
        let headingFont = try XCTUnwrap(ns.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let bodyLocation = (ns.string as NSString).range(of: "Body").location
        let bodyFont = try XCTUnwrap(ns.attribute(.font, at: bodyLocation, effectiveRange: nil) as? NSFont)

        XCTAssertGreaterThan(headingFont.pointSize, bodyFont.pointSize)
        XCTAssertTrue(headingFont.fontName.contains("Bold"), "heading should be bold, got \(headingFont.fontName)")
    }

    func testHTMLCommentIsNotRendered() throws {
        let ns = try typeset("<!-- provenance: hidden note -->\n\n# Title\n\nVisible body.")
        XCTAssertFalse(ns.string.contains("provenance"))
        XCTAssertFalse(ns.string.contains("hidden note"))
        XCTAssertTrue(ns.string.contains("Visible body."))
    }

    func testInlineEmphasisAppliesFontTraits() throws {
        let ns = try typeset("A paragraph with **bold** and *italic* words.")
        XCTAssertTrue(ns.string.contains("bold"))
        XCTAssertTrue(ns.string.contains("italic"))

        let boldLocation = (ns.string as NSString).range(of: "bold").location
        let boldFont = try XCTUnwrap(ns.attribute(.font, at: boldLocation, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(boldFont.fontName.contains("Bold"), "strong emphasis should be bold, got \(boldFont.fontName)")

        let italicLocation = (ns.string as NSString).range(of: "italic").location
        let italicFont = try XCTUnwrap(ns.attribute(.font, at: italicLocation, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(italicFont.fontName.contains("Italic"), "emphasis should be italic, got \(italicFont.fontName)")
    }

    func testTextUsesFixedBlackColorForDarkModeSafety() throws {
        let ns = try typeset("Body paragraph text.")
        let color = try XCTUnwrap(ns.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        // Fixed black (not dynamic textColor) so a dark-mode import can't bake near-white
        // glyphs onto the white page.
        let rgb = try XCTUnwrap(color.usingColorSpace(.deviceRGB))
        XCTAssertEqual(rgb.brightnessComponent, 0, accuracy: 0.01)
    }
}
