import Foundation

/// Resolves the bundled CC0 sample/onboarding document (`SampleDocument.pdf`).
///
/// Uses the same hand-rolled, non-trapping bundle resolution as `L10n`: SwiftPM's
/// generated `Bundle.module` accessor calls `fatalError` when `Orifold_Orifold.bundle`
/// can't be located, which once turned a packaging omission into a launch crash-loop
/// (see docs/CRASH_AUDIT_PLAN.md). Here the stakes are lower — a missing asset just
/// hides the "Open sample document" affordance — but the same rule applies: degrade to
/// `nil`, never trap.
enum SampleDocument {
    static let fileName = "SampleDocument"
    static let fileExtension = "pdf"

    #if SWIFT_PACKAGE
    private final class BundleAnchor {}
    /// Probe every layout the resource bundle can sit in (shipped .app, CLI binary,
    /// `swift test` sibling, framework-embedded) without invoking SwiftPM's trapping
    /// `Bundle.module`. Mirrors `L10n.bundle`.
    private static let bundle: Bundle = {
        let bundleName = "Orifold_Orifold.bundle"
        let anchor = Bundle(for: BundleAnchor.self)
        let candidates: [URL?] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
            Bundle.main.bundleURL.deletingLastPathComponent(),
            anchor.resourceURL,
            anchor.bundleURL,
            anchor.bundleURL.deletingLastPathComponent(),
            anchor.executableURL?.deletingLastPathComponent(),
        ]
        for base in candidates {
            guard let url = base?.appendingPathComponent(bundleName),
                  let found = Bundle(url: url) else { continue }
            return found
        }
        return .main
    }()
    #else
    private final class BundleAnchor {}
    private static let bundle = Bundle(for: BundleAnchor.self)
    #endif

    /// The bundled sample PDF's URL, or `nil` if the asset isn't present in this build.
    static var url: URL? {
        bundle.url(forResource: fileName, withExtension: fileExtension)
    }
}
