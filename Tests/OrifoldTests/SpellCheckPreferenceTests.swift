import XCTest
@testable import Orifold

final class SpellCheckPreferenceTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: SpellCheckPreference.defaultsKey)
        super.tearDown()
    }

    func testDefaultsToEnabled() {
        UserDefaults.standard.removeObject(forKey: SpellCheckPreference.defaultsKey)
        XCTAssertTrue(SpellCheckPreference.isEnabled)
    }

    func testPersistsDisabled() {
        SpellCheckPreference.isEnabled = false
        XCTAssertFalse(SpellCheckPreference.isEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: SpellCheckPreference.defaultsKey))
    }
}
