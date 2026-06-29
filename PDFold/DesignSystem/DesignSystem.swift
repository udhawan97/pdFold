import SwiftUI
import AppKit

// MARK: - Adaptive color helper

extension Color {
    init(light lightColor: NSColor, dark darkColor: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua: return darkColor
            default:        return lightColor
            }
        })
    }
}

// MARK: - SwiftUI semantic color tokens

extension Color {
    /// Warm neutral ground behind PDF pages
    static let dsCanvas = Color(
        light: NSColor(srgbRed: 0.925, green: 0.918, blue: 0.886, alpha: 1),   // #ECEAE2
        dark:  NSColor(srgbRed: 0.102, green: 0.102, blue: 0.094, alpha: 1))   // #1A1A18

    /// Panels: sidebar, inspector, popovers
    static let dsSurface = Color(
        light: NSColor(srgbRed: 0.980, green: 0.976, blue: 0.961, alpha: 1),   // #FAF9F5
        dark:  NSColor(srgbRed: 0.137, green: 0.133, blue: 0.125, alpha: 1))   // #232220

    /// Raised cards, thumbnails
    static let dsCard = Color(
        light: NSColor(srgbRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),   // #FFFFFF
        dark:  NSColor(srgbRed: 0.165, green: 0.161, blue: 0.149, alpha: 1))   // #2A2926

    /// Primary clay accent — used sparingly
    static let dsAccent = Color(
        light: NSColor(srgbRed: 0.788, green: 0.392, blue: 0.259, alpha: 1),   // #C96442
        dark:  NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1))   // #D97757

    /// Soft accent fill for selection backgrounds and hover tints
    static let dsAccentSoft = Color(
        light: NSColor(srgbRed: 0.788, green: 0.392, blue: 0.259, alpha: 0.14),
        dark:  NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 0.22))

    static let dsTextPrimary = Color(
        light: NSColor(srgbRed: 0.102, green: 0.098, blue: 0.082, alpha: 1),   // #1A1915
        dark:  NSColor(srgbRed: 0.925, green: 0.922, blue: 0.882, alpha: 1))   // #ECEAE1

    static let dsTextSecondary = Color(
        light: NSColor(srgbRed: 0.341, green: 0.329, blue: 0.294, alpha: 1),   // #57544B
        dark:  NSColor(srgbRed: 0.690, green: 0.678, blue: 0.635, alpha: 1))   // #B0ADA2

    static let dsTextTertiary = Color(
        light: NSColor(srgbRed: 0.549, green: 0.533, blue: 0.486, alpha: 1),   // #8C887C
        dark:  NSColor(srgbRed: 0.478, green: 0.467, blue: 0.431, alpha: 1))   // #7A776E

    /// Hairlines and dividers
    static let dsSeparator = Color(
        light: NSColor(white: 0, alpha: 0.08),
        dark:  NSColor(white: 1, alpha: 0.10))

    // MARK: Annotation palette (replaces raw .yellow / .systemBlue)
    static let dsHighlightYellow    = Color(red: 0.984, green: 0.886, blue: 0.604)  // #FBE29A
    static let dsAnnotationCoral    = Color(red: 0.910, green: 0.627, blue: 0.541)  // #E8A08A
    static let dsAnnotationSage     = Color(red: 0.659, green: 0.765, blue: 0.627)  // #A8C3A0
    static let dsAnnotationSky      = Color(red: 0.624, green: 0.753, blue: 0.859)  // #9FC0DB
    static let dsAnnotationLavender = Color(red: 0.765, green: 0.702, blue: 0.859)  // #C3B3DB

    static let annotationSwatches: [(Color, NSColor)] = [
        (.dsHighlightYellow,    .dsAnnotationYellow),
        (.dsAnnotationCoral,    NSColor(srgbRed: 0.910, green: 0.627, blue: 0.541, alpha: 1)),
        (.dsAnnotationSage,     NSColor(srgbRed: 0.659, green: 0.765, blue: 0.627, alpha: 1)),
        (.dsAnnotationSky,      NSColor(srgbRed: 0.624, green: 0.753, blue: 0.859, alpha: 1)),
        (.dsAnnotationLavender, NSColor(srgbRed: 0.765, green: 0.702, blue: 0.859, alpha: 1)),
    ]
}

// MARK: - NSColor semantic tokens (for AppKit/PDFKit code)

extension NSColor {
    static let dsCanvasNS: NSColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.102, green: 0.102, blue: 0.094, alpha: 1)
            : NSColor(srgbRed: 0.925, green: 0.918, blue: 0.886, alpha: 1)
    }
    static let dsSurfaceNS: NSColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.137, green: 0.133, blue: 0.125, alpha: 1)
            : NSColor(srgbRed: 0.980, green: 0.976, blue: 0.961, alpha: 1)
    }

    // Annotation palette as NSColor
    static let dsAnnotationYellow   = NSColor(srgbRed: 0.984, green: 0.886, blue: 0.604, alpha: 1)
    static let dsAnnotationCoralNS  = NSColor(srgbRed: 0.910, green: 0.627, blue: 0.541, alpha: 1)
    static let dsAnnotationSageNS   = NSColor(srgbRed: 0.659, green: 0.765, blue: 0.627, alpha: 1)
    static let dsAnnotationSkyNS    = NSColor(srgbRed: 0.624, green: 0.753, blue: 0.859, alpha: 1)
    static let dsAnnotationLavNS    = NSColor(srgbRed: 0.765, green: 0.702, blue: 0.859, alpha: 1)

    /// Default ink stroke color
    static let dsInk = NSColor(srgbRed: 0.18, green: 0.33, blue: 0.62, alpha: 1)

    /// Clay accent for AppKit drawing (BoundaryPage, etc.)
    static let dsAccentNS: NSColor = NSColor(name: nil) { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)
            : NSColor(srgbRed: 0.788, green: 0.392, blue: 0.259, alpha: 1)
    }
}

// MARK: - Spacing (4-pt grid)

extension CGFloat {
    static let dsXS:  CGFloat = 4
    static let dsSM:  CGFloat = 8
    static let dsMD:  CGFloat = 12
    static let dsLG:  CGFloat = 16
    static let dsXL:  CGFloat = 24
    static let dsXXL: CGFloat = 32
}

// MARK: - Corner radii

extension CGFloat {
    static let dsRadiusSm: CGFloat = 6
    static let dsRadiusMd: CGFloat = 10
    static let dsRadiusLg: CGFloat = 16
}

// MARK: - Elevation

extension View {
    func dsElevation() -> some View {
        shadow(color: .black.opacity(0.07), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Typography scale

extension Font {
    /// Serif display — wordmark and empty-state headline only
    static func dsDisplay(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
    static func dsTitle()    -> Font { .system(size: 17, weight: .semibold) }
    static func dsHeadline() -> Font { .system(size: 15, weight: .semibold) }
    static func dsBody()     -> Font { .system(size: 14, weight: .regular) }
    static func dsCaption()  -> Font { .system(size: 12, weight: .regular) }
}
