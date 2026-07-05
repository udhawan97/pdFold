import Foundation

/// Localized-string lookup for non-SwiftUI contexts (error enums, PetBuddy
/// messages) that can't inherit the `.environment(\.locale:)` override applied
/// to the view tree. Reads the same `orifoldLanguage` preference SwiftUI's
/// `LanguageManager` writes, so both stay in sync without shared mutable state.
enum L10n {
    /// `String(localized:)` resolves its string catalog from `bundle` if given, else
    /// falls back to `Bundle.main` — which is the *host process's* main bundle, not
    /// necessarily where `Localizable.xcstrings` actually lives. That default is wrong
    /// for the `OrifoldTests` target: it runs as a standalone XCTest bundle injected
    /// into the app via `BUNDLE_LOADER` rather than a `TEST_HOST`-hosted process, so
    /// `Bundle.main` there is the xctest runner, and every lookup silently falls back
    /// to printing the raw key. Anchoring to the bundle that actually contains this
    /// type (compiled into Orifold.app regardless of which process loaded it) resolves
    /// correctly in both the shipping app and the test target.
    private final class BundleAnchor {}
    private static let bundle = Bundle(for: BundleAnchor.self)

    static var currentLocale: Locale {
        let stored = UserDefaults.standard.string(forKey: LanguageManager.storageKey)
        let language = stored.flatMap(SupportedLanguage.init(rawValue:)) ?? .system
        return SupportedLanguage.resolvedLocale(for: language)
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle, locale: currentLocale)
    }

    static func string(_ key: StaticString, defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: bundle, locale: currentLocale)
    }

    /// Builds a display string from a catalog entry that contains `%@`/`%lld`-style
    /// format placeholders. Use this for interpolated `Text`/`Button` sites instead of
    /// `Text("key \(arg)")` — the latter's runtime lookup key is a compiler-derived
    /// format string, not the literal source syntax, so a catalog entry authored with
    /// the literal `\(arg)` text never actually matches at lookup time.
    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: String(localized: String.LocalizationValue(key), bundle: bundle, locale: currentLocale), arguments: args)
    }
}
