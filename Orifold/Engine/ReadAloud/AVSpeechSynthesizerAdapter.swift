import AVFoundation
import Foundation

/// The production `SpeechSynthesizing`: a thin wrapper around `AVSpeechSynthesizer`.
///
/// It exists so `ReadAloudController` can be unit-tested against a fake, keeping all real
/// audio behaviour behind this one seam. The controller never touches AVFoundation directly —
/// it only speaks/pauses/stops through the protocol and receives range/finish callbacks.
///
/// `AVSpeechSynthesizerDelegate` methods are delivered on the main thread (the same context
/// speaking was started from), which is where `ReadAloudController` — a `@MainActor` type —
/// lives, so forwarding the callbacks straight through is safe.
final class AVSpeechSynthesizerAdapter: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    var onWillSpeakRange: ((NSRange) -> Void)?
    var onFinishUtterance: (() -> Void)?

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float) {
        let utterance = AVSpeechUtterance(string: text)
        // `rate` is a multiplier of the platform default; scale then clamp to the engine's
        // legal band so a user-picked speed can never push it out of range.
        let scaled = AVSpeechUtteranceDefaultSpeechRate * rate
        utterance.rate = min(max(scaled, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        // Use the system's current-language default voice (BCP-47), so read-aloud sounds
        // native to the user's locale without gating on voice quality/availability.
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        synthesizer.speak(utterance)
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        onWillSpeakRange?(characterRange)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinishUtterance?()
    }
}
