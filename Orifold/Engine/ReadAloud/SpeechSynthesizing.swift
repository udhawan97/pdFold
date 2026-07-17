import Foundation

/// The seam between `ReadAloudController` (a pure, testable state machine) and the platform
/// speech engine. The real implementation (`AVSpeechSynthesizerAdapter`) wraps
/// `AVSpeechSynthesizer`; tests inject a fake that fires the callbacks by hand, so the
/// controller's behaviour can be verified without ever producing audio.
///
/// `rate` is a *multiplier* of the platform's default speech rate (1.0 == normal), so the
/// controller and its callers stay free of any AVFoundation constant. The adapter maps it
/// onto `AVSpeechUtteranceDefaultSpeechRate`.
protocol SpeechSynthesizing: AnyObject {
    /// Fired as the engine is about to speak a sub-range of the current utterance. The range
    /// is **utterance-relative** (offsets into the text passed to `speak`), not page-relative;
    /// the controller adds the current chunk's page offset to produce a page-global highlight.
    var onWillSpeakRange: ((NSRange) -> Void)? { get set }
    /// Fired when the current utterance finishes speaking naturally (not on stop).
    var onFinishUtterance: (() -> Void)? { get set }

    func speak(_ text: String, rate: Float)
    func pause()
    func resume()
    func stopSpeaking()
}
