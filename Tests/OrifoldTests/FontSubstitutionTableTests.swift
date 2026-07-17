import XCTest
@testable import Orifold

/// Covers the metric-compatible font substitution table (Feature E1): PDF font names
/// for the standard unembedded families (Arial, Times New Roman, Courier New, Calibri,
/// Cambria) map to the bundled open metric-equivalents, while unknown or
/// already-substituted names return nil. Also locks the subset-tag/style normalization
/// so it mirrors `WorkspaceViewModel.fontFamilyRoot` (subset "+" only at distance 6).
final class FontSubstitutionTableTests: XCTestCase {
    // MARK: familyRoot

    func testFamilyRootStripsSubsetTagAndStyleSuffix() {
        XCTAssertEqual(FontSubstitution.familyRoot("ABCDEF+Helvetica-Bold"), "helvetica")
        XCTAssertEqual(FontSubstitution.familyRoot("Arial-BoldMT"), "arial")
        XCTAssertEqual(FontSubstitution.familyRoot("Calibri"), "calibri")
        XCTAssertEqual(FontSubstitution.familyRoot("ArialMT"), "arialmt")
    }

    /// The subset tag is exactly six upper-case letters plus "+"; a "+" at any other
    /// distance is part of the real name and must NOT be stripped (mirrors the
    /// `distance == 6` rule in `WorkspaceViewModel.fontFamilyRoot`).
    func testFamilyRootOnlyStripsSubsetTagAtDistanceSix() {
        XCTAssertEqual(FontSubstitution.familyRoot("AB+Helvetica"), "ab+helvetica")
        XCTAssertEqual(FontSubstitution.familyRoot("ABCDEFG+Helvetica"), "abcdefg+helvetica")
    }

    // MARK: substituteFamily — known families

    func testSubstituteFamilyMapsCoreMetricEquivalents() {
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "ArialMT"), "Liberation Sans")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "TimesNewRomanPSMT"), "Liberation Serif")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "CourierNewPSMT"), "Liberation Mono")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "Calibri"), "Carlito")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "Cambria"), "Caladea")
    }

    func testSubstituteFamilyHandlesSubsetTaggedNames() {
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "ABCDEF+ArialMT"), "Liberation Sans")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "BCDEFG+TimesNewRomanPSMT"), "Liberation Serif")
    }

    func testSubstituteFamilyHandlesBoldAndItalicVariants() {
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "Arial-BoldMT"), "Liberation Sans")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "Arial-ItalicMT"), "Liberation Sans")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "TimesNewRomanPS-BoldItalicMT"), "Liberation Serif")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "CourierNewPS-BoldMT"), "Liberation Mono")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "Calibri-Italic"), "Carlito")
        XCTAssertEqual(FontSubstitution.substituteFamily(for: "Cambria-Bold"), "Caladea")
    }

    // MARK: substituteFamily — no substitution

    func testSubstituteFamilyReturnsNilForUnknownFonts() {
        XCTAssertNil(FontSubstitution.substituteFamily(for: "Helvetica"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: "Symbol"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: "ArialNarrow"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: ""))
    }

    /// A font that's already one of our bundled substitutes must not be substituted again
    /// (the wiring calls `substituteFamily(for:) ?? original`, so a non-nil here would
    /// pointlessly re-map the font onto itself and could loop family resolution).
    func testSubstituteFamilyReturnsNilForAlreadySubstitutedFonts() {
        XCTAssertNil(FontSubstitution.substituteFamily(for: "Liberation Sans"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: "LiberationSans"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: "LiberationSerif-Bold"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: "Carlito"))
        XCTAssertNil(FontSubstitution.substituteFamily(for: "Caladea-BoldItalic"))
    }
}
