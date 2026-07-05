import XCTest
@testable import Orifold

final class NightModeSettingsTests: XCTestCase {
    func testAppAppearanceModeMapsToExpectedColorSchemes() {
        XCTAssertNil(AppAppearanceMode.system.colorScheme)
        XCTAssertEqual(AppAppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppAppearanceMode.dark.colorScheme, .dark)
    }

    func testNightModeSettingsClampPersistedValuesIntoSupportedRange() {
        let settings = NightModeSettings(warmth: -0.4, intensity: 1.7, dimming: 2.2).clamped

        XCTAssertEqual(settings.warmth, 0)
        XCTAssertEqual(settings.intensity, 1)
        XCTAssertEqual(settings.dimming, 1)
    }

    func testNightModePresetsUseDistinctWarmthAndDimmingLevels() {
        XCTAssertLessThan(NightModePreset.gentle.settings.warmth, NightModePreset.amber.settings.warmth)
        XCTAssertLessThan(NightModePreset.gentle.settings.dimming, NightModePreset.amber.settings.dimming)
    }
}
