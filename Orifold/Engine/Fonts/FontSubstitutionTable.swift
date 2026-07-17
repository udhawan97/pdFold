import Foundation

/// Maps the standard *unembedded* PDF font families (the ones a document references but
/// doesn't carry glyphs for — Arial, Times New Roman, Courier New, Calibri, Cambria) to
/// bundled open fonts with matching glyph metrics. Substituting these instead of blindly
/// falling back to Helvetica keeps edited/inserted text on the original layout: Liberation
/// Sans/Serif/Mono are metric-compatible with Arial/Times New Roman/Courier New, Carlito
/// with Calibri, and Caladea with Cambria.
///
/// The mapping is intentionally narrow. Only the five well-known metric-clone pairs are
/// substituted; every other name (already-embedded fonts, genuinely-installed fonts, our
/// own bundled substitutes) returns `nil` so callers keep the real font.
enum FontSubstitution {
    /// Normalized family root → bundled metric-compatible family name. Keys are the output
    /// of `normalizedRoot` (subset tag + style suffix + foundry noise stripped, lowercased,
    /// spaces removed), so a whole family — regular, bold, italic, bold-italic, and any
    /// subset-tagged copy — collapses onto one entry.
    private static let table: [String: String] = [
        "arial": "Liberation Sans",
        "timesnewroman": "Liberation Serif",
        "couriernew": "Liberation Mono",
        "calibri": "Carlito",
        "cambria": "Caladea",
    ]

    /// Normalized roots of the fonts we ourselves bundle, so `substituteFamily` never
    /// re-substitutes a name that's already one of our substitutes (the wiring calls
    /// `substituteFamily(for:) ?? original`; a non-nil result here would map a font onto
    /// itself).
    private static let bundledSubstituteRoots: Set<String> = [
        "liberationsans", "liberationserif", "liberationmono", "carlito", "caladea",
    ]

    /// The family root of a PDF font name: strips a six-letter subset tag (`ABCDEF+`) and
    /// any style suffix after the first `-`, then lowercases. Mirrors
    /// `WorkspaceViewModel.fontFamilyRoot` exactly, including its `distance == 6` subset
    /// rule — a `+` anywhere else is part of the real name and is kept.
    /// Example: `"ABCDEF+Helvetica-Bold"` → `"helvetica"`.
    static func familyRoot(_ name: String) -> String {
        var base = name
        if let plus = base.firstIndex(of: "+"), base.distance(from: base.startIndex, to: plus) == 6 {
            base = String(base[base.index(after: plus)...])
        }
        if let dash = base.firstIndex(of: "-") { base = String(base[..<dash]) }
        return base.lowercased()
    }

    /// The bundled metric-compatible family to substitute for `pdfFontName`, or `nil` when
    /// the font is unknown (leave it alone) or is already one of our bundled substitutes.
    static func substituteFamily(for pdfFontName: String) -> String? {
        let root = normalizedRoot(pdfFontName)
        guard !bundledSubstituteRoots.contains(root) else { return nil }
        return table[root]
    }

    /// `familyRoot` plus the foundry suffixes PostScript names tack on (`ArialMT`,
    /// `TimesNewRomanPSMT`, `TimesNewRomanPS-…`) and any interior spaces, so a family's
    /// regular member (`ArialMT` → `arialmt`) and its styled members (`Arial-BoldMT` →
    /// `arial`) both collapse to the same lookup key (`arial`).
    private static func normalizedRoot(_ name: String) -> String {
        var root = familyRoot(name).replacingOccurrences(of: " ", with: "")
        for suffix in ["psmt", "ps", "mt"] where root.count > suffix.count && root.hasSuffix(suffix) {
            root = String(root.dropLast(suffix.count))
            break
        }
        return root
    }
}
