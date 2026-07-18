import CoreGraphics
import CoreText
import Foundation

/// The outline of a hanko seal: circular (the traditional 丸印) or square (the 角印 used by
/// companies).
enum HankoShape: String, Codable, CaseIterable {
    case circle
    case square
}

/// The inputs to a procedural hanko seal — a border shape, the name/kanji it carries, and
/// the ink colour (shu-iro vermillion by default). Deliberately value-typed and free of any
/// UI/AppKit dependency so the renderer stays a pure CoreGraphics/CoreText unit.
struct HankoConfig: Equatable {
    var shape: HankoShape
    var text: String
    var inkColor: CGColor

    /// Shu-iro (朱色), the vermillion of a carved seal — matches `Color.dsSignatureAccent`
    /// (light) so an on-canvas preview and the baked export share one ink.
    static let defaultInk = CGColor(srgbRed: 0.749, green: 0.267, blue: 0.173, alpha: 1)

    init(shape: HankoShape, text: String, inkColor: CGColor = HankoConfig.defaultInk) {
        self.shape = shape
        self.text = text
        self.inkColor = inkColor
    }
}

enum HankoError: Error, Equatable, LocalizedError {
    case emptyText
    case invalidSize

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return L10n.string("error.hanko.emptyText")
        case .invalidSize:
            return L10n.string("error.hanko.invalidSize")
        }
    }
}

/// Renders a hanko seal entirely from vector geometry. The border is a filled ring
/// (outer + inner contour, even-odd) and the name is a top-to-bottom column of glyph
/// outlines fitted inside it — the traditional vertical CJK reading order. Nothing is
/// rasterised and no font is embedded: glyphs become `CGPath`s the same way
/// `SignatureAppearanceRenderer` outlines a typed signature, so an exported seal costs a
/// few hundred bytes of path data instead of a subset of a multi-megabyte CJK typeface.
enum HankoRenderer {
    /// The combined seal geometry (border ring + fitted glyph column) as one `CGPath`.
    /// Used on-canvas and by tests; export goes through ``pdfAppearanceStream(for:bounds:)``
    /// which fills the border and glyphs with the correct winding rules separately.
    static func outlinePath(for config: HankoConfig, in rect: CGRect) throws -> CGPath {
        try validateSize(rect)
        let border = borderRingPath(for: config.shape, in: rect)
        let glyphs = try glyphColumnPath(for: config, in: glyphArea(for: config.shape, in: rect))
        let combined = CGMutablePath()
        combined.addPath(border)
        combined.addPath(glyphs)
        return combined
    }

    /// A self-contained PDF Form XObject stream: sets the ink colour once, fills the border
    /// ring even-odd, then fills the glyph column non-zero (the native rule for font
    /// outlines, so counters like the hole in 田 render correctly). References no font.
    static func pdfAppearanceStream(for config: HankoConfig, bounds: CGRect) throws -> PDFAppearanceStream {
        try validateSize(bounds)
        let box = CGRect(origin: .zero, size: bounds.size)
        let border = borderRingPath(for: config.shape, in: box)
        let glyphs = try glyphColumnPath(for: config, in: glyphArea(for: config.shape, in: box))
        let color = config.inkColor.hankoRGBComponents
        let stream = """
        q
        \(color.red.pdfNumber) \(color.green.pdfNumber) \(color.blue.pdfNumber) rg
        \(border.pdfPathOperators)
        f*
        \(glyphs.pdfPathOperators)
        f
        Q
        """
        return PDFAppearanceStream(xobject: Data(stream.utf8), bbox: box)
    }

    /// Draws the seal into a live CoreGraphics context (on-canvas preview / export bake).
    static func draw(_ config: HankoConfig, in rect: CGRect, context: CGContext) throws {
        try validateSize(rect)
        let border = borderRingPath(for: config.shape, in: rect)
        let glyphs = try glyphColumnPath(for: config, in: glyphArea(for: config.shape, in: rect))
        context.saveGState()
        context.setFillColor(config.inkColor)
        context.addPath(border)
        context.fillPath(using: .evenOdd)
        context.addPath(glyphs)
        context.fillPath()
        context.restoreGState()
    }

    // MARK: - Geometry

    private static func validateSize(_ rect: CGRect) throws {
        guard rect.width > 0, rect.height > 0 else { throw HankoError.invalidSize }
    }

    /// Border stroke thickness scaled to the seal, with a floor so a small preview still
    /// reads as a seal rather than a hairline.
    private static func borderThickness(in rect: CGRect) -> CGFloat {
        max(2, min(rect.width, rect.height) * 0.055)
    }

    /// The filled ring: an outer contour and a concentric inner contour. Filled even-odd,
    /// this leaves the paper showing through the middle — a stroked-looking border with no
    /// stroke operator needed.
    private static func borderRingPath(for shape: HankoShape, in rect: CGRect) -> CGPath {
        let outer = rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.035)
        let thickness = borderThickness(in: rect)
        let inner = outer.insetBy(dx: thickness, dy: thickness)
        let path = CGMutablePath()
        switch shape {
        case .circle:
            path.addEllipse(in: outer)
            if inner.width > 0, inner.height > 0 { path.addEllipse(in: inner) }
        case .square:
            path.addRect(outer)
            if inner.width > 0, inner.height > 0 { path.addRect(inner) }
        }
        return path
    }

    /// The rectangle the glyph column is fitted into — inside the ring, and for a circle
    /// inscribed within it so glyphs don't collide with the curve.
    private static func glyphArea(for shape: HankoShape, in rect: CGRect) -> CGRect {
        let outer = rect.insetBy(dx: rect.width * 0.035, dy: rect.height * 0.035)
        let thickness = borderThickness(in: rect)
        let inner = outer.insetBy(dx: thickness * 1.6, dy: thickness * 1.6)
        switch shape {
        case .square:
            return inner
        case .circle:
            // Largest centred square that fits inside the inner circle: side = d / √2.
            let side = min(inner.width, inner.height) / 2.0.squareRoot()
            return CGRect(x: inner.midX - side / 2, y: inner.midY - side / 2, width: side, height: side)
        }
    }

    // MARK: - Glyph column

    /// Vertically stacks each character's outline (top-to-bottom, horizontally centred),
    /// uniformly scaled so the whole column fits `area`. Whitespace is dropped. Throws
    /// `.emptyText` when nothing renderable remains.
    private static func glyphColumnPath(for config: HankoConfig, in area: CGRect) throws -> CGPath {
        let trimmed = config.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HankoError.emptyText }
        guard area.width > 0, area.height > 0 else { throw HankoError.invalidSize }

        let font = sealFont(size: baseGlyphSize)
        // One outline per non-whitespace character, in reading order.
        let glyphs: [CGPath] = trimmed.compactMap { character in
            guard !character.isWhitespace else { return nil }
            let path = glyphLinePath(String(character), font: font)
            let box = path.boundingBoxOfPath
            return (box.isNull || box.width <= 0 || box.height <= 0) ? nil : path
        }
        guard !glyphs.isEmpty else { throw HankoError.emptyText }

        let boxes = glyphs.map { $0.boundingBoxOfPath }
        let spacing = baseGlyphSize * 0.14
        let stackHeight = boxes.reduce(0) { $0 + $1.height } + spacing * CGFloat(glyphs.count - 1)
        let maxWidth = boxes.map(\.width).max() ?? 1
        guard stackHeight > 0, maxWidth > 0 else { throw HankoError.emptyText }

        let scale = min(area.width / maxWidth, area.height / stackHeight)
        // Centre the scaled column vertically inside the area, then lay glyphs downward.
        var cursorTop = area.midY + (stackHeight * scale) / 2
        let column = CGMutablePath()
        for (path, box) in zip(glyphs, boxes) {
            var transform = CGAffineTransform.identity
                .translatedBy(
                    x: area.midX - box.midX * scale,
                    y: cursorTop - box.maxY * scale
                )
                .scaledBy(x: scale, y: scale)
            if let placed = path.copy(using: &transform) {
                column.addPath(placed)
            }
            cursorTop -= (box.height + spacing) * scale
        }
        return column
    }

    private static let baseGlyphSize: CGFloat = 100

    /// Prefers the bundled Shippori Mincho (Feature F2) for an authentic carved-seal look,
    /// then Japanese/Chinese mincho system faces. Whichever base font is chosen, the CoreText
    /// line below cascades to a font that actually contains each character, so a glyph never
    /// silently vanishes even if the preferred face lacks it.
    static func sealFont(size: CGFloat) -> CTFont {
        let candidates = [
            "ShipporiMincho-Regular",
            "HiraMinProN-W3", "HiraMinPro-W3",
            "HiraginoMincho-W3",
            "STSongti-SC-Regular", "Songti SC",
            "PingFangSC-Regular",
        ]
        for name in candidates {
            let font = CTFontCreateWithName(name as CFString, size, nil)
            let resolved = CTFontCopyPostScriptName(font) as String
            if resolved.caseInsensitiveCompare(name) == .orderedSame {
                return font
            }
        }
        return CTFontCreateUIFontForLanguage(.system, size, "ja" as CFString)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    /// Outlines a run of text through CoreText, cascading per run to whatever font actually
    /// holds each glyph — mirrors `SignatureAppearanceRenderer.textOutlinePath`.
    private static func glyphLinePath(_ text: String, font: CTFont) -> CGPath {
        let attributed = NSAttributedString(string: text, attributes: [
            kCTFontAttributeName as NSAttributedString.Key: font
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return CGMutablePath() }
        let outline = CGMutablePath()

        for run in runs {
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }

            let attributes = CTRunGetAttributes(run) as NSDictionary
            // Guard on the real CoreFoundation type before trusting the value as a CTFont —
            // a plain `as?` to a CF type always succeeds and would trap on a surprise.
            let runFont: CTFont
            if let value = attributes[kCTFontAttributeName],
               CFGetTypeID(value as CFTypeRef) == CTFontGetTypeID() {
                runFont = value as! CTFont
            } else {
                runFont = font
            }
            var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
            var positions = [CGPoint](repeating: .zero, count: glyphCount)
            CTRunGetGlyphs(run, CFRange(location: 0, length: glyphCount), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: glyphCount), &positions)

            for index in 0..<glyphCount {
                guard let glyphPath = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
                let transform = CGAffineTransform(translationX: positions[index].x, y: positions[index].y)
                outline.addPath(glyphPath, transform: transform)
            }
        }
        return outline
    }
}

// MARK: - PDF content-stream helpers
//
// Local copies of the number/point/colour formatting `SignatureAppearanceRenderer` keeps
// file-private; kept here so the two renderers stay independent.

private extension CGColor {
    var hankoRGBComponents: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let converted = converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil) ?? self
        let components = converted.components ?? [0, 0, 0, alpha]
        if components.count >= 3 { return (components[0], components[1], components[2]) }
        let gray = components.first ?? 0
        return (gray, gray, gray)
    }
}

private extension CGFloat {
    var pdfNumber: String {
        let value = abs(self) < 0.000_001 ? 0 : self
        return String(format: "%.4f", Double(value))
    }
}

private extension CGPoint {
    var pdfPoint: String { "\(x.pdfNumber) \(y.pdfNumber)" }
}

private extension CGPath {
    /// The path as PDF content-stream construction operators (m/l/c/h), no paint operator —
    /// the caller appends `f` or `f*`. Quadratic segments (TrueType/mincho glyphs) are
    /// promoted to cubics.
    var pdfPathOperators: String {
        var commands: [String] = []
        var current = CGPoint.zero
        applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                current = element.points[0]
                commands.append("\(current.pdfPoint) m")
            case .addLineToPoint:
                current = element.points[0]
                commands.append("\(current.pdfPoint) l")
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let end = element.points[1]
                let control1 = CGPoint(
                    x: current.x + (2.0 / 3.0) * (control.x - current.x),
                    y: current.y + (2.0 / 3.0) * (control.y - current.y)
                )
                let control2 = CGPoint(
                    x: end.x + (2.0 / 3.0) * (control.x - end.x),
                    y: end.y + (2.0 / 3.0) * (control.y - end.y)
                )
                commands.append("\(control1.pdfPoint) \(control2.pdfPoint) \(end.pdfPoint) c")
                current = end
            case .addCurveToPoint:
                current = element.points[2]
                commands.append("\(element.points[0].pdfPoint) \(element.points[1].pdfPoint) \(element.points[2].pdfPoint) c")
            case .closeSubpath:
                commands.append("h")
            @unknown default:
                break
            }
        }
        return commands.joined(separator: "\n")
    }
}
