import XCTest
@testable import Orifold

/// Feature C3: a single smoke test for the real `AVSpeechSynthesizer` adapter. It never
/// asserts on audio — the point is only that the adapter constructs its synthesizer and tears
/// down cleanly in a headless CI environment, where `speak` is deliberately never called so no
/// audio device is touched.
final class AVSpeechSynthesizerAdapterTests: XCTestCase {

    func testConstructsAndStopsWithoutCrashing() {
        let adapter = AVSpeechSynthesizerAdapter()
        // Stopping with nothing queued must be a safe no-op, not a crash.
        adapter.stopSpeaking()
    }

    func testConformsToSpeechSynthesizing() {
        let adapter: SpeechSynthesizing = AVSpeechSynthesizerAdapter()
        adapter.onWillSpeakRange = { _ in }
        adapter.onFinishUtterance = { }
        adapter.stopSpeaking()
    }
}
