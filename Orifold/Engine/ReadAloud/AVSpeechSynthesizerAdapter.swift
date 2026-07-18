import AVFoundation
import Foundation

/// The production `SpeechSynthesizing`: a thin wrapper around `AVSpeechSynthesizer`.
///
/// It exists so `ReadAloudController` can be unit-tested against a fake, keeping all real
/// audio behaviour behind this one seam. The controller never touches AVFoundation directly —
/// it only speaks/pauses/stops through the protocol and receives range/finish callbacks.
///
/// `AVSpeechSynthesizerDelegate` callbacks drive `@MainActor` state on `ReadAloudController`
/// (its `highlight`/`state`). Their delivery thread isn't contractually guaranteed across OS
/// versions, so the delegate methods hop to the main queue before invoking the closures rather
/// than trust the delivery thread — matching the explicit main hop the downstream highlight
/// bridge already performs. `DispatchQueue.main.async` (not a detached `Task`) preserves the
/// relative order of the will-speak and finish callbacks.
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
        DispatchQueue.main.async { [weak self] in
            self?.onWillSpeakRange?(characterRange)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onFinishUtterance?()
        }
    }
}
