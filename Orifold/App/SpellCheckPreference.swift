import Foundation

/// Backs the Settings toggle and both PDF text editors. Default ON: continuous
/// spell-check is the macOS text-editing convention; the preference exists for
/// users who edit machine-generated text where red underlines are noise.
enum SpellCheckPreference {
    static let defaultsKey = "orifoldSpellCheckEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }
}
