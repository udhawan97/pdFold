# Wave 1 — Quick Wins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Parent doc: `docs/FEATURE_WAVES_MASTER_PLAN.md` (its Global Constraints apply to every task here).

**Goal:** Ship the four zero-dependency quick wins — spell-check in the inline text editor, a document metadata viewer/editor, read-aloud with follow-along highlight, and a bundled CC0 sample document.

**Architecture:** All four are pure Swift/system-framework features. Spell-check is an NSTextView property behind a preference. Metadata rides the already-linked qpdf C API (`qpdf_get_info_key`/`qpdf_set_info_key`) through the existing byte-preserving pipeline. Read-aloud wraps AVSpeechSynthesizer behind a protocol with a pure chunker for testability. The sample document is a build-time-generated, committed PDF asset.

**Tech Stack:** SwiftUI/AppKit, CQPDF (linked), AVFoundation, PDFKit.

## Global Constraints

- All Global Constraints from `docs/FEATURE_WAVES_MASTER_PLAN.md` (L10n ×6, no PDFKit re-serialization, structural validation on byte mutation, release-build check, hands-on click-through, merge+push per feature).
- File anchors below were verified 2026-07-16; **re-grep every anchor before editing** (shared repo).
- Features A–D are independent; each gets its own merge to main. Suggested order: A → B → D → C (C is the largest).

---

## Feature A — Spell-check in the inline text editor

Scope note (verified): system spellcheck covers en/es/fr/hi; **ja/zh-Hans have no system spellcheck** — the Settings caption must say so.

### Task A1: SpellCheckPreference helper

**Files:**
- Create: `Orifold/App/SpellCheckPreference.swift`
- Test: `Tests/OrifoldTests/SpellCheckPreferenceTests.swift`

**Interfaces:**
- Produces: `enum SpellCheckPreference { static var isEnabled: Bool { get set } ; static let defaultsKey = "orifoldSpellCheckEnabled" }`

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SpellCheckPreferenceTests`
Expected: compile FAIL — `cannot find 'SpellCheckPreference' in scope`

- [ ] **Step 3: Write minimal implementation**

```swift
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
```

- [ ] **Step 4: Run test to verify it passes** — `swift test --filter SpellCheckPreferenceTests` → PASS
- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: add spell-check preference (default on)"`

### Task A2: Wire preference into both editors

**Files:**
- Modify: `Orifold/Views/ReadingCanvas.swift` — `InlineEditableTextView` (class at ≈:4670; re-grep `class InlineEditableTextView`) and the FreeText editor NSTextView setup (≈:2289; re-grep `NSTextView(` in the file)
- Test: `Tests/OrifoldTests/SpellCheckPreferenceTests.swift` (extend)

**Interfaces:**
- Consumes: `SpellCheckPreference.isEnabled` (Task A1)
- Produces: both editors call `applySpellCheckPreference()` at setup

- [ ] **Step 1: Write the failing test** (append to the A1 test class)

```swift
    @MainActor
    func testInlineEditorHonorsPreference() {
        SpellCheckPreference.isEnabled = true
        let enabled = InlineEditableTextView(frame: .zero)
        enabled.applySpellCheckPreference()
        XCTAssertTrue(enabled.isContinuousSpellCheckingEnabled)

        SpellCheckPreference.isEnabled = false
        let disabled = InlineEditableTextView(frame: .zero)
        disabled.applySpellCheckPreference()
        XCTAssertFalse(disabled.isContinuousSpellCheckingEnabled)
    }
```

If `InlineEditableTextView` is not visible to tests (`final class` without access modifier is `internal` — visible via `@testable import`), keep as-is.

- [ ] **Step 2: Run** — `swift test --filter SpellCheckPreferenceTests` → FAIL: no `applySpellCheckPreference`
- [ ] **Step 3: Implement.** In `InlineEditableTextView` add:

```swift
    func applySpellCheckPreference() {
        isContinuousSpellCheckingEnabled = SpellCheckPreference.isEnabled
        isGrammarCheckingEnabled = false
        isAutomaticSpellingCorrectionEnabled = false  // never rewrite PDF text silently
    }
```

Call it from the editor's existing setup path (grep for where `InlineEditableTextView` is instantiated/configured — expect the `InlineTextEditorOverlay` at ≈:2643) and in the FreeText editor's NSTextView configuration block. Do NOT enable `isAutomaticTextReplacementEnabled`.

- [ ] **Step 4: Run** — PASS. Also run full `swift test` (no regressions).
- [ ] **Step 5: Commit** — `git commit -m "feat: continuous spell-check in inline and FreeText editors"`

### Task A3: Settings toggle + L10n

**Files:**
- Modify: `Orifold/Views/SettingsView.swift` (Form, after the appearance picker), `Orifold/Resources/Localizable.xcstrings`
- Test: existing L10n coverage test (must pass with new keys in all 6 languages)

- [ ] **Step 1:** Add keys `settings.spellcheck.label` ("Spell-check while editing") and `settings.spellcheck.caption` ("Underlines possible misspellings in editable text. Available for English, Spanish, French, and Hindi.") to `Localizable.xcstrings` in en, es, fr, hi, ja, zh-Hans.
- [ ] **Step 2:** Run L10n coverage test (grep test names for `Localization`/`Coverage`, run that filter) → PASS.
- [ ] **Step 3:** Add the toggle to `SettingsView` (pattern-match the existing rows; storage via `@AppStorage(SpellCheckPreference.defaultsKey) private var spellCheckEnabled = true`):

```swift
    Toggle(L10n.string("settings.spellcheck.label", locale: locale), isOn: $spellCheckEnabled)
    Text(L10n.string("settings.spellcheck.caption", locale: locale))
        .font(.caption).foregroundStyle(.secondary)
```

Live-apply: the editors read the preference at editing-session start, which is acceptable (next edit session picks it up); if a `.onChange` hook into an active editor is cheap at the call site found in A2, add it.

- [ ] **Step 4:** `swift test` → all PASS. Hands-on: build, open a PDF, edit text with a typo → red underline; toggle off in Settings → new edit session has none.
- [ ] **Step 5:** Commit; merge + push to main. Update master-plan Status table.

---

## Feature B — Metadata viewer/editor

Verified: today the app only write-stamps a title at import (`PDFKitEngine.swift` ≈528). `qpdf_get_info_key`/`qpdf_set_info_key` confirmed in the linked `libQPDF.a` and `qpdf-c.h` (≈:339/:347). These touch the **Info dictionary only** — the UI therefore pairs the editor with an optional "also remove XMP metadata" action that reuses the shipped sanitize pass (`PDFSanitizationOptions.removesMetadata`).

### Task B1: Read metadata via qpdf

**Files:**
- Create: `Orifold/Engine/PDFMetadataService.swift`
- Test: `Tests/OrifoldTests/PDFMetadataServiceTests.swift`

**Interfaces:**
- Produces:
  - `struct PDFDocumentMetadata: Equatable { var title: String? = nil; var author: String? = nil; var subject: String? = nil; var keywords: String? = nil }` (defaults required — tests use `PDFDocumentMetadata()`)
  - `enum PDFMetadataService { static func read(from data: Data, password: String?) throws -> PDFDocumentMetadata; static func write(_ metadata: PDFDocumentMetadata, to data: Data, password: String?) throws -> Data }`
- Consumes: `CQPDF` C API; follow the init/read/error idioms already in `QPDFService.swift` (`qpdf_init` ≈:298, `qpdf_read_memory` ≈:310, error handling via the existing `hasErrors` helper — reuse, don't duplicate).

- [ ] **Step 1: Write the failing test.** Fixture: build a PDF in-test via PDFKit document attributes (PDFKit writes them into the Info dict):

```swift
import XCTest
import PDFKit
@testable import Orifold

final class PDFMetadataServiceTests: XCTestCase {
    private func fixture(title: String?, author: String?) -> Data {
        let doc = PDFDocument()
        let page = PDFPage()
        doc.insert(page, at: 0)
        var attrs: [PDFDocumentAttribute: Any] = [:]
        if let title { attrs[.titleAttribute] = title }
        if let author { attrs[.authorAttribute] = author }
        doc.documentAttributes = attrs
        return doc.dataRepresentation()!  // fixture creation only — never product code
    }

    func testReadsTitleAndAuthor() throws {
        let data = fixture(title: "折り紙", author: "Gami")
        let meta = try PDFMetadataService.read(from: data, password: nil)
        XCTAssertEqual(meta.title, "折り紙")
        XCTAssertEqual(meta.author, "Gami")
        XCTAssertNil(meta.subject)
    }

    func testMissingInfoDictYieldsAllNil() throws {
        let meta = try PDFMetadataService.read(from: fixture(title: nil, author: nil), password: nil)
        XCTAssertEqual(meta, PDFDocumentMetadata())
    }
}
```

- [ ] **Step 2: Run** — `swift test --filter PDFMetadataServiceTests` → compile FAIL.
- [ ] **Step 3: Implement** `read` (open via the same `qpdf_init`/`qpdf_read_memory` sequence `QPDFService` uses — extract/reuse its private open helper if access allows; otherwise mirror it):

```swift
import Foundation
import CQPDF

struct PDFDocumentMetadata: Equatable {
    var title: String? = nil
    var author: String? = nil
    var subject: String? = nil
    var keywords: String? = nil
}

enum PDFMetadataService {
    static func read(from data: Data, password: String? = nil) throws -> PDFDocumentMetadata {
        try QPDFService.withOpenDocument(data: data, password: password) { qpdf in
            func info(_ key: String) -> String? {
                key.withCString { keyPtr -> String? in
                    guard let raw = qpdf_get_info_key(qpdf, keyPtr) else { return nil }
                    let value = String(cString: raw)
                    return value.isEmpty ? nil : value
                }
            }
            return PDFDocumentMetadata(
                title: info("/Title"), author: info("/Author"),
                subject: info("/Subject"), keywords: info("/Keywords"))
        }
    }
}
```

`QPDFService.withOpenDocument(data:password:_:)` may not exist under that name — locate the existing open/cleanup wrapper (grep `qpdf_read_memory` and `qpdf_cleanup` in `QPDFService.swift`) and expose/reuse it rather than writing a second lifecycle. Note: `qpdf_get_info_key` returns a pointer owned by qpdf — copy to `String` immediately, never store the pointer.

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** — `feat: read PDF Info-dict metadata via qpdf`.

### Task B2: Write metadata via qpdf

**Files/Test:** same as B1.

- [ ] **Step 1: Failing tests** (append):

```swift
    func testWriteRoundTrip() throws {
        let edited = try PDFMetadataService.write(
            PDFDocumentMetadata(title: "New Title", author: "Ori", subject: "S", keywords: "a, b"),
            to: fixture(title: "Old", author: nil), password: nil)
        let meta = try PDFMetadataService.read(from: edited, password: nil)
        XCTAssertEqual(meta.title, "New Title")
        XCTAssertEqual(meta.keywords, "a, b")
        XCTAssertEqual(PDFDocument(data: edited)?.pageCount, 1)   // structure intact
    }

    func testNilClearsKey() throws {
        let edited = try PDFMetadataService.write(
            PDFDocumentMetadata(), to: fixture(title: "Old", author: "A"), password: nil)
        let meta = try PDFMetadataService.read(from: edited, password: nil)
        XCTAssertNil(meta.title)
        XCTAssertNil(meta.author)
    }
```

- [ ] **Step 2: Run** → FAIL (no `write`).
- [ ] **Step 3: Implement** `write`: open, `qpdf_set_info_key(qpdf, "/Title", value)` for each non-nil field; for nil fields verify clear semantics in the vendored `qpdf-c.h` (header doc states whether passing NULL/empty removes the key — if not, remove via the trailer `/Info` object using the `qpdf_oh_remove_key` idiom already used at `QPDFService.swift` ≈:234). Serialize with the same `qpdf_init_write_memory` (+ preserve-object-streams params) sequence `QPDFService` uses, then run the output through the existing structural-validation gate before returning.
- [ ] **Step 4: Run** → PASS, plus full `swift test`. **Step 5: Commit** — `feat: write PDF Info-dict metadata via qpdf`.

### Task B3: Workspace integration (bytes + undo + dirty state)

**Files:**
- Modify: `Orifold/ViewModels/WorkspaceViewModel.swift`
- Test: `Tests/OrifoldTests/PDFMetadataServiceTests.swift` (view-model-level test)

**Interfaces:**
- Produces: `WorkspaceViewModel.applyMetadataEdit(_ metadata: PDFDocumentMetadata, alsoRemoveXMP: Bool)` — mutates the active member's preserved bytes, registers named undo, marks document dirty, bumps `structureRevision`.

- [ ] **Step 1:** Locate the existing byte-mutation precedent: grep `WorkspaceViewModel.swift` for the OCR or compression apply path (search `PDFOCRService` / `PDFCompressionService` call sites) — note how it (a) swaps member bytes, (b) reconciles ops↔bytes, (c) registers undo *inside* its group with a name (undo naming lesson from v0.8.10), (d) triggers canvas refresh (`combinedPDF` swap / `structureRevision`).
- [ ] **Step 2: Failing test** — apply metadata to a one-member workspace, assert `try PDFMetadataService.read` on the member's current bytes returns the new title, `undoManager.canUndo == true` with action name set, and undo restores the old title.
- [ ] **Step 3: Implement** `applyMetadataEdit` following that precedent exactly; `alsoRemoveXMP: true` additionally runs the sanitize metadata-strip pass (reuse the `PDFSanitizationOptions.removesMetadata` machinery — grep its qpdf implementation) on the same bytes.
- [ ] **Step 4:** `swift test` → PASS. **Step 5: Commit** — `feat: metadata edits flow through preserving pipeline with undo`.

### Task B4: Inspector UI + L10n

**Files:**
- Modify: `Orifold/Views/InspectorView.swift` (`InspectorInfoView`, tab enum at :13 stays unchanged — this extends the existing **Info** tab), `Orifold/Resources/Localizable.xcstrings`

- [ ] **Step 1:** Add a "Document metadata" section to `InspectorInfoView`: four `TextField`s (title/author/subject/keywords) bound to `@State` copies seeded from `PDFMetadataService.read` of the active member, an Apply button calling `applyMetadataEdit`, a caption warning when XMP is present ("This document also carries XMP metadata, which may repeat old values.") with a "Remove XMP too" toggle. Disable for encrypted members lacking a stored password.
- [ ] **Step 2:** L10n keys ×6: `inspector.metadata.section`, `.title`, `.author`, `.subject`, `.keywords`, `.apply`, `.xmpWarning`, `.removeXMP`. Coverage test → PASS.
- [ ] **Step 3:** `swift test`; hands-on: edit title → Apply → export → open exported file in Preview → Get Info shows new title; Undo restores.
- [ ] **Step 4:** Commit; merge + push. Update master Status table.

---

## Feature C — Read-aloud with follow-along highlight

Design: `SpeechChunker` (pure — sentences + global offsets) → `ReadAloudController` (state machine over a `SpeechSynthesizing` protocol; real adapter wraps `AVSpeechSynthesizer`) → highlight bridge (global offset → `PDFSelection` via `page.selection(for: NSRange)`; **never** assert `PDFPage.string` equality in CI tests).

### Task C1: SpeechChunker

**Files:** Create `Orifold/Engine/ReadAloud/SpeechChunker.swift`; Test `Tests/OrifoldTests/SpeechChunkerTests.swift`.

**Interfaces:**
- Produces: `struct SpeechChunk: Equatable { let text: String; let pageIndex: Int; let rangeInPage: NSRange }` and `enum SpeechChunker { static func chunks(forPageText text: String, pageIndex: Int) -> [SpeechChunk] }` (sentence-granular via `NLTokenizer(unit: .sentence)` — NaturalLanguage is macOS-14-safe).

- [ ] **Step 1: Failing tests:** two sentences → two chunks with correct `rangeInPage` (NSRange over UTF-16, matching what `page.selection(for:)` expects); empty/whitespace text → `[]`; emoji/CJK text ranges stay UTF-16-consistent (`("こんにちは。ありがとう。", 0)` → 2 chunks, ranges reconstruct the substrings via `(text as NSString).substring(with:)`).
- [ ] **Step 2:** Run filter → FAIL. **Step 3:** Implement with `NLTokenizer`, converting `Range<String.Index>` → `NSRange(range, in: text)`. **Step 4:** PASS. **Step 5:** Commit `feat: sentence chunker for read-aloud`.

### Task C2: ReadAloudController + fake synthesizer

**Files:** Create `Orifold/Engine/ReadAloud/ReadAloudController.swift`, `Orifold/Engine/ReadAloud/SpeechSynthesizing.swift`; Test `Tests/OrifoldTests/ReadAloudControllerTests.swift`.

**Interfaces:**
- Produces:

```swift
protocol SpeechSynthesizing: AnyObject {
    var onWillSpeakRange: ((NSRange) -> Void)? { get set }   // utterance-relative
    var onFinishUtterance: (() -> Void)? { get set }
    func speak(_ text: String, rate: Float)
    func pause(); func resume(); func stopSpeaking()
}

@MainActor final class ReadAloudController: ObservableObject {
    enum State: Equatable { case idle, speaking, paused }
    @Published private(set) var state: State
    @Published private(set) var highlight: (pageIndex: Int, rangeInPage: NSRange)?
    init(synthesizer: SpeechSynthesizing, pageTextProvider: @escaping (Int) -> String?, pageCount: @escaping () -> Int)
    func start(fromPage: Int); func pause(); func resume(); func stop()
}
```

- [ ] **Step 1: Failing tests** with a `FakeSynthesizer` (records spoken texts; test fires `onWillSpeakRange`/`onFinishUtterance` manually): start speaks chunk 1 of page N; utterance-relative range + chunk offset = correct page-global highlight; finishing last chunk of a page advances to next page; finishing last page → `.idle` and `highlight == nil`; pause/resume/stop transitions; stop clears highlight.
- [ ] **Step 2:** FAIL. **Step 3:** Implement (queue chunks per page via `SpeechChunker`, one utterance at a time — simpler and pause-friendly). **Step 4:** PASS. **Step 5:** Commit `feat: read-aloud controller state machine`.

### Task C3: AVSpeechSynthesizer adapter + PDF highlight bridge

**Files:** Create `Orifold/Engine/ReadAloud/AVSpeechSynthesizerAdapter.swift`; Modify `Orifold/Views/ReadingCanvas.swift` (highlight application), `Orifold/ViewModels/WorkspaceViewModel.swift` (controller ownership + `pageTextProvider`).

- [ ] **Step 1:** Adapter: `AVSpeechSynthesizer` + `AVSpeechSynthesizerDelegate`, mapping `speechSynthesizer(_:willSpeakRangeOfSpeechString:utterance:)` → `onWillSpeakRange`. No unit test asserts audio; one smoke test constructs the adapter and calls `stopSpeaking()` (no crash).
- [ ] **Step 2:** `pageTextProvider`: use the page's `attributedString.string` (NOT `.string` — CI quirk) from the composed document; highlight bridge: `page.selection(for: chunkRange)` → `pdfView.setCurrentSelection(selection, animate: false)` + `pdfView.go(to: selection)` on page change; clear on stop. Manual-verification feature — keep logic in the controller (already tested), bridge stays thin.
- [ ] **Step 3:** Full `swift test` → PASS. **Step 4:** Commit `feat: AV adapter + follow-along highlight bridge`.

### Task C4: UI + L10n

**Files:** Modify `Orifold/App/AppCommands.swift`, `Orifold/Views/ContentView.swift` (More menu ≈:3065), `Localizable.xcstrings`.

- [ ] **Step 1:** More-menu entry + app-menu command "Read Aloud" (start from current page; toggles to "Stop Reading" while active); small floating capsule while active: play/pause, stop, rate menu (0.9×/1×/1.25×; map to `AVSpeechUtteranceDefaultSpeechRate` multiples). Keys ×6: `readaloud.start`, `.stop`, `.pause`, `.resume`, `.rate`. Coverage test PASS.
- [ ] **Step 2:** `swift test`; release build; hands-on: open sample doc → Read Aloud → sentences highlight in sync, page auto-advances, pause/resume/stop behave; VoiceOver-off machine sanity.
- [ ] **Step 3:** Commit; merge + push. Update master Status table.

---

## Feature D — CC0 sample/onboarding document

Text: **"My Lord Bag of Rice" from Yei Theodora Ozaki, _Japanese Fairy Tales_ (1908)** — author died 1932 (>70y → PD worldwide), published pre-1929 (US PD), thematically on-brand. Source from Project Gutenberg **stripping all Gutenberg license/trademark text** (their trademark policy requires removal when redistributing outside their license), or Standard Ebooks if it carries the title.

### Task D1: Generate + commit the sample PDF

**Files:**
- Create: `scripts/generate-sample-document.md` (the typeset source, markdown), `Orifold/Resources/SampleDocument.pdf` (committed artifact)
- Test: `Tests/OrifoldTests/SampleDocumentTests.swift`

- [ ] **Step 1:** Fetch the story text; strip PG boilerplate/trademark; save as `scripts/generate-sample-document.md` with a one-line provenance header (`<!-- Source: Japanese Fairy Tales, Ozaki, 1908 — public domain worldwide; PG boilerplate removed per PG trademark policy -->`).
- [ ] **Step 2:** Generate the PDF **through the app's own markdown import pipeline** so it looks exactly like a real import (env-gated generator test, run once locally):

```swift
    func testGenerateSampleDocument() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ORIFOLD_GENERATE_SAMPLE"] == "1")
        // Load scripts/generate-sample-document.md, run it through the same
        // PDFKitEngine markdown→PDF path import uses (grep `AttributedString(markdown:`
        // in PDFKitEngine.swift ≈:369 for the entry point), write to
        // Orifold/Resources/SampleDocument.pdf.
    }
```

Run: `ORIFOLD_GENERATE_SAMPLE=1 swift test --filter SampleDocumentTests` → writes the asset; commit it. Target ≤1.5 MB.

- [ ] **Step 3: Bundle-presence test** (always-on):

```swift
    func testSampleDocumentBundledAndOpens() throws {
        let url = try XCTUnwrap(SampleDocument.url)
        let doc = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThanOrEqual(doc.pageCount, 3)
    }
```

- [ ] **Step 4:** Add `.copy("Resources/SampleDocument.pdf")` to `Package.swift` resources (≈:33–38); create `Orifold/App/SampleDocument.swift` with `enum SampleDocument { static var url: URL? }` using the same safe bundle-resolution approach as `L10n` (never the trapping `Bundle.module` accessor — crash-loop lesson, see `L10n.swift` comments). Run test → PASS.
- [ ] **Step 5:** Add a CC0/provenance note to `THIRD-PARTY-NOTICES.md`. Commit — `feat: bundle CC0 sample document`.

### Task D2: Empty-state entry point

**Files:** Modify `Orifold/Views/EmptyStateView.swift`, `Localizable.xcstrings`.

- [ ] **Step 1:** "Open sample document" button under the existing empty-state actions: copies `SampleDocument.url` to a unique temp URL (`FileManager.default.temporaryDirectory`, name "Sample — My Lord Bag of Rice.pdf") and routes it through the normal import path (grep the Add Files handler for the entry function) — the user edits a disposable copy, never the bundle asset. Key ×6: `emptystate.sample.button`.
- [ ] **Step 2:** `swift test` + coverage test → PASS. Hands-on: fresh launch → button visible → opens 3+-page styled document; edit + export works; Gami reacts to open (existing `addFile` PetEvent fires via the normal import path — no extra work).
- [ ] **Step 3:** Commit; merge + push. Update master Status table.

---

## Wave close-out

- [ ] Bump version (check current — v0.8.14 landed 2026-07-16 — coordinate with whatever main says today) in `project.yml`/`Package.swift` locations the release script expects; write `docs/release-vX.Y.Z.md` following the existing release-note format.
- [ ] `swift build -c release` (silgen/WMO check) + full `swift test`.
- [ ] Delete stale local Orifold.app copies (mdfind sweep), install fresh build, click through all four features end-to-end.
- [ ] Tick Wave 1 rows in `docs/FEATURE_WAVES_MASTER_PLAN.md`; merge + push to main.
