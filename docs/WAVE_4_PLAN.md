# Wave 4 — Positioning Features Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Parent doc: `docs/FEATURE_WAVES_MASTER_PLAN.md` (its Global Constraints apply to every task); source roadmap items #3 (offline translation), #13 (archival-readiness/PDF-A-lite), #14 (structure/reading-order inspector), #10 (CJK font pack), #16 (CBZ import) in `docs/OPEN_SOURCE_FEATURE_ROADMAP.md`.

**Goal:** Ship the five "positioning" features — offline translation (the repo's **first** `#available(macOS 15)` gate), archival-readiness hints (PDF/A-*lite*, read-only), a structure / reading-order inspector, a CJK font pack (gated behind a mandatory embedding spike), and CBZ→PDF import (the only feature adding a new SPM dependency, ZIPFoundation). All offline; four features are zero-runtime-dependency, one adds ZIPFoundation (MIT).

## FEASIBILITY VERDICTS (verified 2026-07-17 against the vendored binaries on branch `friendly-helper-claude/app-feature-roadmap-6b4c71`)

| Feature | Verdict | Why |
|---|---|---|
| **L — Offline translation (macOS 15 gate)** | ✅ Doable, **zero new `@_silgen_name` bindings**, repo's FIRST `#available(macOS 15)` | `TranslationSession` verified macOS 15.0+, third-party-capable, SwiftUI-only (obtained via `.translationTask`; cannot be instantiated directly, must not be stored in a long-lived model). CI's Xcode 16.4 ships the macOS 15 SDK → compiles behind `#available`. Text source already exists (`PDFTextAnalysisEngine` / `pdfView.currentSelection` / `page.attributedString`). **High confidence.** |
| **M — Archival-readiness hints (PDF/A-lite)** | ✅ Doable, code-only, **1 new `@_silgen_name` binding** (`FPDFCatalog_IsTagged`) | Every check is reachable through the existing `import CQPDF` object surgery (`qpdf_is_encrypted`, `/OpenAction`+`/AA`+`/Names/JavaScript` walk, `/Metadata` XMP presence, `/OutputIntents`, `/Resources/Font` embedded-file walk) plus one exported-but-unbound PDFium catalog flag. **Med-High.** Read-only; **never branded "PDF/A validation."** |
| **N — Structure / reading-order inspector** | ✅ Doable, code-only, **9 new `@_silgen_name` bindings** | All `FPDF_StructTree_*` / `FPDF_StructElement_*` symbols verified exported by the dylib and **not yet bound** in Swift. Read-only tagged-PDF tree + "untagged" a11y warning + per-image alt-text presence. **Med-High.** Tag *writing* stays out of scope. |
| **O — CJK font pack (+ mandatory spike)** | ⚠️ **SPIKE-GATED** — O1 gates O2/O3; code-only, **≥1 new `@_silgen_name` binding** (`FPDFText_LoadFont`) | `FPDFText_LoadFont` verified exported/unbound. **Spike FIRST (O1):** embed a large CJK font into an edited PDF and measure export bloat. If PDFium doesn't subset (>2–3 MB/doc), collapse scope to display-only substitution + export warning (Wave 2's 4D posture). **Depends on Wave 2's `FontRegistrar`** — which does **NOT exist on this branch** (Wave 2 unshipped; see Anchor drift). **Medium confidence.** |
| **P — CBZ → PDF import** | ✅ Doable, **NEW SPM dependency (ZIPFoundation, MIT)** | ZIPFoundation v0.9.20, MIT, macOS 10.11+, in-memory `Archive(data:accessMode:.read)` — sandbox-fine (read-only, user-selected file). Unzip images → existing images→PDF merge lane (`PDFKitEngine.renderImage` :1031 + the `PDFDocument().insert` merge pattern :1057/:1083). Natural sort already in-repo (`localizedStandardCompare`). **Med-High.** EPUB explicitly excluded. |

**Recommended intra-wave order: N → M → L → P → O.**
- **N first** — it adds the most bindings (9); land them while fresh and `swift build -c release` immediately (silgen/WMO hazard). It creates the wave's PDFium-structure binding file.
- **M second** — one binding (`FPDFCatalog_IsTagged`), reuses the same release-build discipline + the rich `QPDFService` object-surgery surface.
- **L third** — the `#available(macOS 15)` gate; self-contained, no binary risk, establishes the repo's first gate pattern cleanly.
- **P fourth** — isolates the one new SPM dependency (ZIPFoundation) in its own commit.
- **O last** — spike-gated (O1 gates everything after) and depends on Wave 2's `FontRegistrar`; its scope may collapse after the spike, so do it when the wave's binding/gate/dependency patterns are all already proven.

**Total task count: 19 TDD tasks** (N: 4, M: 4, L: 4, P: 4, O: 3 — **O2 and O3 are conditional on the O1 spike result**).

---

## Anchor drift vs master brief (re-verified 2026-07-17 — RE-GREP before editing; shared repo moves fast)

- **⚠️ Waves 1/2/3 are NOT implemented on this branch** (Status table in the master plan is all `☐`; `nm`/grep confirm none of their code exists). Concretely:
  - **`FontRegistrar` / `FontSubstitution` / `AFMMetricsStore` do NOT exist** (Wave 2 deliverables). Feature **O**'s brief says "Reuse Wave 2's FontRegistrar" — **that dependency is unmet on this branch.** O must either run after Wave 2 lands, or O1's spike self-provides minimal font-registration plumbing (`CTFontManagerRegisterFontsForURL`, process scope). Flagged in O1.
  - **`Shippori Mincho` is NOT bundled** (Wave 2 F2). O's display-substitution fallback assumes it; if Wave 2 hasn't shipped, O must bundle it or scope down.
  - **`InspectorView.Tab` has 6 cases** (`info/tags/comments/markup/decorate/ocr`) — **no `.attachments`** (Wave 3 I4 unshipped) and no `.structure`. Feature **N** inserts `.structure` into the 6-case enum.
- **`PDFKitEngine.renderImage`** — master brief 4E said `≈313`; **actual `:1031`** (`private static`; the images→PDF one-pager). `:313` is an unrelated import branch. DRIFT — use `:1031` (matches Wave 3's note).
- **`FPDFCatalog_IsTagged`** — roadmap says "verified present." Confirmed by `nm` on `macos-arm64_x86_64/PDFium.framework/PDFium`. **NOT bound** in Swift (grep empty). M binds it.
- **`FPDF_StructTree_*` / `FPDF_StructElement_*`** — roadmap says "verified present, read-only." Confirmed exported by `nm`; **none bound** in Swift (grep empty). N binds 9 of them.
- **`FPDFText_LoadFont`** — confirmed exported by `nm`; **NOT bound**. Signature (fpdf_edit.h:1348): `FPDF_FONT FPDFText_LoadFont(FPDF_DOCUMENT, const uint8_t* data, uint32_t size, int font_type, FPDF_BOOL cid)`.
- **`QPDFService` object-surgery surface** — brief 4B said "≈229–283." **Actual:** `withQPDF(_:description:password:)` = `:304` (internal, reusable); `write(_:configure:)` = `:346`; `isStructurallySound` = `:30`; `sanitized(_:removingMetadata:)` = `:98` (removes `/OpenAction` :103, `/AA` :104, `/Names/JavaScript` :107, `/Names/EmbeddedFiles` :108, `/Info`+`/Metadata` :111-112); XMP presence check (`qpdf_oh_has_key(root,"/Metadata")`) = `:124`; private helpers `hasKey` `:238`, `removeKey` `:242`, `replaceKey` `:246`. DRIFT (helpers start :238, not :229).
- **`qpdf_is_encrypted`** = `qpdf-c.h:355` (also `qpdf_allow_*` :358-374). **`qpdf_get_info_key`/`qpdf_set_info_key`** = :339/:347. All in the `CQPDF` module — no new binding surface.
- **`PDFMetadataService`** EXISTS (`Orifold/Engine/PDFMetadataService.swift`; `read` :37, `write` :59, `infoValue` :115) and already reuses `QPDFService.withQPDF`. **Reuse it in M** for Info-dict reads instead of re-opening qpdf.
- **`PDFTextAnalysisEngine`** = `:116`; rich `FPDFText_*` bindings already declared file-private `:11–86` (`FPDFText_LoadPage`, `CountChars`, `GetUnicode`, `GetText` via analysis). CI-safe text extraction lives here.
- **Text selection (Feature L source):** `pdfView.currentSelection` (`ReadingCanvas.swift:619/640/1442`), `viewModel.currentSelectionPageRefs` (`WorkspaceViewModel.swift:2711`); page text via `page.attributedString?.string` (`:3829`, already chosen over `.string` for the CI quirk).
- **More-menu routing:** `enum MoreRoute` = `ContentView.swift:3033`; `requestMoreRoute(_:)` :640; `pendingMoreRoute` state :196; the dismiss→present hand-off `onChange` :2992; `.sheet(isPresented:)` precedents :379/:432; `inspectorTab` state :180.
- **Inspector body switch:** `InspectorView.swift` `Tab` enum :13, `iconName` :21, `titleKey` :35, body `switch tab` :80 (`case .ocr: InspectorOCRView` :80). N follows this exactly.
- **PDFium binding files/pattern:** `PDFiumObjectBindings.swift` (`poe_` prefix; UTF-16LE buffer idiom at `poe_MarkGetName` :104; `poe_InsertObjectAtIndex` :100; `poe_GenerateContent` :105). `PDFCompressionService.swift` (`FPDFCompression_SaveAsCopy` :80 internal, `FPDFCompressionFileWrite` :87). `PDFiumProcessingEngine.swift` (`FPDF_LoadMemDocument` :12, `FPDF_CloseDocument` :19, `FPDF_GetPageCount` :22, global `pdfiumLock` :4). Reuse — never re-declare.
- **Manifests:** `Package.swift` deps :11–17, target deps :21–27, resources :33–39. `project.yml` `packages:` :18–31, target `dependencies:` :48–58, `resources:` :42–47, `CFBundleDocumentTypes` :75–115, version `CFBundleShortVersionString "0.8.14"` / `CFBundleVersion "20"` :63–64.
- **UTType extension** = `WorkspaceDocument.swift:6` (`static let orifold*`). **Natural sort** precedents: `FolderImportScanner.swift:66` (`localizedStandardCompare`), `PDFKitEngine.swift:1403` (`.numeric` compare). **Import entry** = `WorkspaceViewModel.importFiles(urls:)` :789.
- **L10n:** `L10n.string(forKey:locale:)` = `App/L10n.swift:80`; `L10n.string(_:locale:)` :84; safe resolver probes `Bundle.main.*` :41–44 (never trapping `Bundle.module`). **`LanguageManager`** (`App/LanguageManager.swift`) enumerates 6 langs (en/es/fr/hi/zh-Hans/ja). **`LocalizationCoverageTests.supportedLanguages`** = `["es","fr","hi","zh-Hans","ja"]` (5; `en` is the base) — every new key needs **all 6** localizations or the test fails.
- **CI pin:** `.github/workflows/ci.yml:21` `runs-on: macos-15`, `:24` `DEVELOPER_DIR: /Applications/Xcode_16.4.app/...`; regenerates pbxproj via `xcodegen generate` (:84). **Xcode 16.4 → macOS 15 SDK** → Feature L compiles; macOS 26 APIs do not exist here (out of scope).

## Binding-surface `nm` findings (`macos-arm64_x86_64` slice of the vendored PDFium framework)

`nm -gU .build/artifacts/pdfiumbinary/PDFium/PDFium.xcframework/macos-arm64_x86_64/PDFium.framework/PDFium`:

- **Feature M:** `_FPDFCatalog_IsTagged` **T** (exported). `_FPDF_GetMetaText` **T** (XMP fallback read, not needed if using qpdf `/Metadata`).
- **Feature N:** `_FPDF_StructTree_GetForPage`, `_FPDF_StructTree_Close`, `_FPDF_StructTree_CountChildren`, `_FPDF_StructTree_GetChildAtIndex`, `_FPDF_StructElement_GetType`, `_FPDF_StructElement_GetAltText`, `_FPDF_StructElement_GetTitle`, `_FPDF_StructElement_CountChildren`, `_FPDF_StructElement_GetChildAtIndex` — all **T** (exported). (`_FPDF_StructElement_GetActualText`, `_GetObjType` also present if needed.)
- **Feature O:** `_FPDFText_LoadFont`, `_FPDFText_LoadStandardFont`, `_FPDFPageObj_CreateTextObj`, `_FPDFText_SetText` — all **T**. (Placing spike text also reuses `poe_InsertObjectAtIndex` / `poe_GenerateContent` already bound.)
- Grep of `Orifold/` confirms **none** of the above are currently `@_silgen_name`-bound. All struct-element string getters use the standard PDFium UTF-16LE buffer idiom: `unsigned long Get*(handle, void* buffer, unsigned long buflen)` → returns byte length incl. the UTF-16 NUL; call once with `buffer=nil` to size, then again to fill (mirror `poe_MarkGetName`, `PDFiumObjectBindings.swift:104`). `unsigned long` maps to Swift `UInt` (the repo precedent).

## Cross-cutting gotchas (apply to EVERY task)

- **(a) xcstrings is ORDER-PRESERVING.** Insert keys with a Python `OrderedDict` round-trip (no `sort_keys`), at the sorted position. Each entry: `{"extractionState":"manual","localizations":{lang:{"stringUnit":{"state":"translated","value":…}}}}` for **all 6** langs `en/es/fr/hi/ja/zh-Hans`. `LocalizationCoverageTests` fails on any missing lang.
- **(b) L10n.** All user-facing strings via `L10n.string(_, locale:)`; `RawLocalizationKeyLeakTests` fails on raw dotted keys in `Text/Label/Button/Toggle/Menu/help/…`. SwiftUI views that must live-switch read `@Environment(\.locale)` and thread it into `L10n.string(forKey:locale:)`.
- **(c) Safe bundle resolution** mirroring `L10n.swift:41–44` (probe `Bundle.main` URLs); NEVER the trapping `Bundle.module` accessor. (O's font-pack + P's bundled fixtures both touch resources.)
- **(d) CI-safe text extraction.** NEVER assert `PDFPage.string` equality (Xcode 16.4 SDK interleaves/undercounts). Use PDFium `FPDFText_*` (via `PDFTextAnalysisEngine`), `page.attributedString`, or thumbnail pixel brightness (`NSBitmapImageRep.colorAt → brightnessComponent`).
- **(e) New `@_silgen_name` bindings (N, M, O).** One binding per C symbol **per Swift type** across the whole module. Two bindings of the same symbol with **different** signatures pass debug + `swift test` but **break `swift build -c release`** (WMO merge) — the `FPDF_SaveAsCopy`-dup lesson (ff08f10). Use a fresh prefix per new file (`pst_` for N, `arc_` for M, `cjk_` for O); do NOT re-bind symbols already declared `poe_*`/`FPDFCompression_*`/in `PDFiumProcessingEngine`/`PDFTextAnalysisEngine`. **Release-build after any binding change, before moving on.**
- **(f) Any bundled resource must be in BOTH manifests.** Add to `Package.swift` `resources:` (`.copy(...)`) AND `project.yml` `targets.Orifold.resources:`, then run `xcodegen generate`. SPM and Xcode read different manifests — this bit us this session. (O's optional font pack is a *download*, not bundled; but O's display-substitution Shippori — if Wave 2 didn't ship it — and P's committed test fixtures are bundled.)
- **(g) New SPM dependency (P only).** ZIPFoundation goes in `Package.swift` `dependencies:` **and** the `Orifold` target `dependencies:`, **and** `project.yml` `packages:` **and** `targets.Orifold.dependencies:`, then `xcodegen generate`. Update `Package.resolved` (commit it). THIRD-PARTY-NOTICES entry in the same commit.
- **(h) `#available(macOS 15)` is the gating pattern (L only, repo's first).** Gate at the **feature-surface** level: the menu item is hidden/disabled below 15; the `.translationTask`-hosting view and any `import Translation` type reference sit behind `if #available(macOS 15, *)` / `@available(macOS 15, *)`. Keep the deployment target at 14.0. Verify with `swift build` (targets 14) AND the CI Xcode-16.4 path.
- **(i) Warm-cache focused tests during dev** (`swift test --filter <Suite>`); **ONE full `swift test` per feature**; `swift build -c release` after any binding change (N, M, O); **commit per task; DO NOT push** (recovery branch). Merge/push only if explicitly instructed.

- **Preserving pipeline (applies if bytes mutate).** N, M, L are **read-only** (no byte mutation). P produces a *new* PDF from images (no preserved-text concern — it's a fresh raster doc). O's spike writes bytes via PDFium `FPDF_SaveAsCopy` (an already-accepted re-serialization path) — gate any written output with `QPDFService.isStructurallySound`. Never re-serialize an existing member via PDFKit `dataRepresentation()`.

---

# Feature N — Structure / reading-order inspector  *(do FIRST — the most binding-adding feature)*

Design: PDFium struct-tree bindings (release-build immediately) → pure `StructureInspectionService` (bytes → tree model + alt-text tally + tagged flag) → Inspector "Structure" tab (OutlineGroup + untagged warning) → L10n. **Read-only throughout** — no byte mutation, no tag writing.

### Task N1: PDFium structure-tree bindings (+ release-build gate)

**Files:**
- Create: `Orifold/Engine/PDFiumStructureBindings.swift`
- Test: `Tests/OrifoldTests/PDFiumStructureBindingsTests.swift`

**Interfaces (produces — new bindings, `pst_` prefix, mirroring `PDFiumObjectBindings.swift` style):**

```swift
import Foundation

// fpdf_structtree.h — read-only tagged-PDF structure. Symbols verified exported via `nm`;
// NOT previously bound. Page lifecycle (FPDF_LoadPage/ClosePage) is reused from PDFiumObjectBindings
// (`poe_LoadPage`/`poe_ClosePage`) and the doc lifecycle from PDFiumProcessingEngine — do NOT re-bind.
@_silgen_name("FPDF_StructTree_GetForPage")
func pst_StructTree_GetForPage(_ page: OpaquePointer?) -> OpaquePointer?          // FPDF_STRUCTTREE
@_silgen_name("FPDF_StructTree_Close")
func pst_StructTree_Close(_ structTree: OpaquePointer?)
@_silgen_name("FPDF_StructTree_CountChildren")
func pst_StructTree_CountChildren(_ structTree: OpaquePointer?) -> Int32
@_silgen_name("FPDF_StructTree_GetChildAtIndex")
func pst_StructTree_GetChildAtIndex(_ structTree: OpaquePointer?, _ index: Int32) -> OpaquePointer?  // FPDF_STRUCTELEMENT

@_silgen_name("FPDF_StructElement_GetType")
func pst_StructElement_GetType(_ element: OpaquePointer?, _ buffer: UnsafeMutableRawPointer?, _ buflen: UInt) -> UInt
@_silgen_name("FPDF_StructElement_GetTitle")
func pst_StructElement_GetTitle(_ element: OpaquePointer?, _ buffer: UnsafeMutableRawPointer?, _ buflen: UInt) -> UInt
@_silgen_name("FPDF_StructElement_GetAltText")
func pst_StructElement_GetAltText(_ element: OpaquePointer?, _ buffer: UnsafeMutableRawPointer?, _ buflen: UInt) -> UInt
@_silgen_name("FPDF_StructElement_CountChildren")
func pst_StructElement_CountChildren(_ element: OpaquePointer?) -> Int32
@_silgen_name("FPDF_StructElement_GetChildAtIndex")
func pst_StructElement_GetChildAtIndex(_ element: OpaquePointer?, _ index: Int32) -> OpaquePointer?

// Shared UTF-16LE getter helper (mirror poe_MarkGetName pattern): size with nil, then fill.
func pst_utf16String(_ read: (UnsafeMutableRawPointer?, UInt) -> UInt) -> String? {
    let needed = read(nil, 0)                      // bytes incl. UTF-16 NUL
    guard needed > 2 else { return nil }           // 2 = just the NUL → empty
    var buf = [UInt8](repeating: 0, count: Int(needed))
    _ = buf.withUnsafeMutableBytes { read($0.baseAddress, UInt($0.count)) }
    return String(bytes: buf.prefix(Int(needed) - 2), encoding: .utf16LittleEndian)
}
```

- Reuse (do NOT re-declare): `poe_LoadPage`/`poe_ClosePage` (PDFiumObjectBindings), `FPDF_LoadMemDocument`/`FPDF_CloseDocument`/`FPDF_GetPageCount` (PDFiumProcessingEngine), global `pdfiumLock`.

- [ ] **Step 1: Failing smoke test** — prove the symbols link + an untagged fixture yields a nil/empty tree:

```swift
import XCTest
import PDFKit
@testable import Orifold

final class PDFiumStructureBindingsTests: XCTestCase {
    func testUntaggedPageHasNoStructTree() throws {
        let doc = PDFDocument(); doc.insert(PDFPage(), at: 0)          // PDFKit — fixture only
        let data = doc.dataRepresentation()!
        pdfiumLock.lock(); defer { pdfiumLock.unlock() }
        let d = data.withUnsafeBytes { FPDF_LoadMemDocument($0.baseAddress, Int32(data.count), nil) }
        defer { FPDF_CloseDocument(d) }
        let page = poe_LoadPage(d, 0); defer { poe_ClosePage(page) }
        let tree = pst_StructTree_GetForPage(page)
        defer { if tree != nil { pst_StructTree_Close(tree) } }
        // Untagged page: tree is nil OR reports zero children — both acceptable link-proofs.
        XCTAssertTrue(tree == nil || pst_StructTree_CountChildren(tree) == 0)
    }
}
```

- [ ] **Step 2: Run** `swift test --filter PDFiumStructureBindingsTests` → FAIL (symbols unbound). **Step 3: Implement** the bindings + helper above. **Step 4:** `swift build -c release` **mandatory** (gotcha (e)), then re-run → PASS. **Step 5: Commit** — `feat: bind FPDF_StructTree/StructElement read-only structure surface`.

**Gotchas:** `FPDF_StructTree_GetForPage` allocates — always `pst_StructTree_Close` it (it does NOT free the page). `unsigned long` → `UInt` (repo precedent, not `Int32`). String getters return **byte** length incl. the UTF-16 NUL; a return of `2` means empty. A `FPDF_STRUCTELEMENT` is owned by its tree — never close elements individually. Deeply nested/cyclic trees: cap recursion depth (≤ 64, mirror `QPDFService` field-walk :266).

### Task N2: StructureInspectionService — bytes → tree model (pure)

**Files:**
- Create: `Orifold/Engine/Structure/StructureInspectionService.swift`
- Test: `Tests/OrifoldTests/StructureInspectionServiceTests.swift`

**Interfaces:**
```swift
struct StructureNode: Equatable {
    let role: String            // /S, e.g. "H1","P","Figure","Table" (normalized to a display role)
    let title: String?          // /T
    let altText: String?        // /Alt
    let children: [StructureNode]
    var isImageLike: Bool { ["Figure", "Formula"].contains(role) }
}
struct PageStructure: Equatable {
    let pageIndex: Int
    let isTagged: Bool
    let roots: [StructureNode]
    var imagesMissingAltText: Int    // Figure nodes with nil/empty altText
}
enum StructureInspectionError: Error, Equatable { case invalidPDF }
enum StructureInspectionService {
    static func inspect(_ data: Data, pageIndex: Int) throws -> PageStructure
    static func documentIsTagged(_ data: Data) -> Bool          // reuse M's binding if landed, else struct-tree presence
}
```
- Consumes: N1 bindings under `pdfiumLock`; `FPDF_LoadMemDocument`/`GetPageCount`/`poe_LoadPage`. Walk `pst_StructTree_GetForPage` → recurse `CountChildren`/`GetChildAtIndex`, reading `GetType`→role, `GetTitle`→title, `GetAltText`→altText for each element via `pst_utf16String`.

- [ ] **Step 1: Failing tests.** A tagged fixture is hard to synthesize with PDFKit (it doesn't emit a struct tree). **Commit a tiny tagged PDF fixture** (`Tests/OrifoldTests/Fixtures/tagged-sample.pdf` with one `H1` + one `P` + one `Figure` with `/Alt`) and an untagged one. Register both fixtures in `Package.swift`/`project.yml` test resources or load via `#filePath`-relative URL (mirror `LocalizationCoverageTests:29`).

```swift
final class StructureInspectionServiceTests: XCTestCase {
    func testTaggedFixtureYieldsExpectedRoles() throws {
        let s = try StructureInspectionService.inspect(taggedFixture(), pageIndex: 0)
        XCTAssertTrue(s.isTagged)
        let roles = flatten(s.roots).map(\.role)
        XCTAssertTrue(roles.contains("H1")); XCTAssertTrue(roles.contains("Figure"))
    }
    func testFigureWithoutAltIsCounted() throws {
        let s = try StructureInspectionService.inspect(taggedFixtureNoAlt(), pageIndex: 0)
        XCTAssertGreaterThan(s.imagesMissingAltText, 0)
    }
    func testUntaggedFixtureFlagsUntagged() throws {
        let s = try StructureInspectionService.inspect(untaggedFixture(), pageIndex: 0)
        XCTAssertFalse(s.isTagged); XCTAssertTrue(s.roots.isEmpty)
    }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** the recursive walk (depth-cap 64; skip cycles by not revisiting). **Step 4:** PASS + full `swift test`. **Step 5: Commit** — `feat: read-only PDF structure inspection service (tree + alt-text tally)`.

**Gotchas:** `StructureNode` must be `Equatable` **without** a UUID `id` (UUIDs break determinism) — SwiftUI `OutlineGroup` can key on `\.self` (Hashable) or an index-path wrapper built in N3. Some producers put the role under `/S` as a name, others map to standard names — normalize (`"H1"..."H6"`, `"P"`, `"Figure"`, `"Table"`, `"LI"`, else pass through). Empty struct tree on a tagged doc is possible per-page (tags on other pages) — `isTagged` should reflect the **catalog** (`FPDFCatalog_IsTagged` or `/MarkInfo /Marked true`), not just this page's tree.

### Task N3: Inspector "Structure" tab UI + wiring

**Files:**
- Modify: `Orifold/Views/InspectorView.swift` (add `case structure = "Structure"` to `Tab` :14–19, `iconName` = `"list.bullet.indent"` :21, `titleKey` = `"inspector.tab.structure"` :35, body `case .structure: InspectorStructureView(viewModel:)` at the :80 switch), add the `InspectorStructureView` struct
- Test: `Tests/OrifoldTests/StructureInspectionServiceTests.swift` (view-model accessor, if one is added)

- [ ] **Step 1:** New tab renders, for the current page: an `OutlineGroup` of `StructureNode` (role + title, a "no alt text" badge on `isImageLike` nodes with nil alt); when `!isTagged`, a prominent **"This document is untagged"** accessibility warning card instead of the tree (explain: screen readers can't determine reading order). Reads `@Environment(\.locale)` and threads it into every `L10n.string(forKey:locale:)`. Compute `PageStructure` lazily off the current page's bytes (cache per `structureRevision`; do NOT recompute each render).
- [ ] **Step 2:** `swift test`; **hands-on** (view-layer): open a tagged PDF → tree shows H1/P/Figure with indentation; open an untagged PDF → warning card; a Figure without alt shows the badge.
- [ ] **Step 3: Commit** — `feat: structure/reading-order inspector tab`.

**Gotchas:** widen or add a `WorkspaceViewModel` accessor that returns the current member's bytes for the active page (mirror how `InspectorOCRView` reaches page data). Recompute only on page change / `structureRevision` bump — struct-tree walks are not free on large docs. `OutlineGroup` needs a stable identity — wrap nodes in an index-path-keyed struct, not a per-render UUID.

### Task N4: L10n ×6 + hands-on

**Files:**
- Modify: `Orifold/Resources/Localizable.xcstrings`
- Test: `LocalizationCoverageTests` + `RawLocalizationKeyLeakTests`

- [ ] **Step 1:** Keys ×6 (`en/es/fr/hi/ja/zh-Hans`): `inspector.tab.structure` ("Structure"), `structure.untagged.title` ("This document is untagged"), `structure.untagged.body` ("It has no tag tree, so screen readers can't reliably determine reading order or describe images."), `structure.noAltText` ("No alt text"), `structure.empty` ("No structure on this page."). Order-preserving insert (gotcha (a)). Coverage + RawLocalizationKeyLeak pass.
- [ ] **Step 2:** Full `swift test` + `swift build -c release` (N added bindings). **Step 3: Commit** — `feat: structure inspector localization (6 languages)`. Tick master Status row.

---

# Feature M — Archival-readiness hints (PDF/A-lite)  *(1 new binding; read-only)*

**Framing rule (non-negotiable):** the UI says **"Archival readiness hints"** and each row is a *hint*, never a verdict. **Never** the words "PDF/A validation," "PDF/A compliant," or "validated." Full PDF/A validation is hundreds of clauses; this is a handful of cheap introspection signals. No conversion, no byte mutation.

Design: `FPDFCatalog_IsTagged` binding + `ArchivalReadinessService` core-flag checks (M1) → fonts-embedded + OutputIntent introspection (M2, the meaty walk) → checklist panel UI (M3) → L10n (M4).

### Task M1: FPDFCatalog_IsTagged binding + ArchivalReadinessService core flags

**Files:**
- Create: `Orifold/Engine/Archival/ArchivalReadinessService.swift` (contains the one binding + the qpdf-based core checks)
- Test: `Tests/OrifoldTests/ArchivalReadinessServiceTests.swift`

**Interfaces:**
```swift
// fpdf_catalog.h — FPDF_BOOL FPDFCatalog_IsTagged(FPDF_DOCUMENT). Verified exported/unbound.
@_silgen_name("FPDFCatalog_IsTagged")
func arc_Catalog_IsTagged(_ document: OpaquePointer?) -> Int32

struct ArchivalReadiness: Equatable {
    var isEncrypted: Bool            // PDF/A forbids encryption → "encrypted" is a FAIL hint
    var hasActiveContent: Bool       // /OpenAction, /AA, or /Names/JavaScript present → FAIL hint
    var allFontsEmbedded: Bool       // M2 fills this
    var hasOutputIntent: Bool        // M2 fills this
    var hasXMPMetadata: Bool         // /Metadata present
    var isTagged: Bool               // FPDFCatalog_IsTagged || /MarkInfo /Marked
}
enum ArchivalReadinessService {
    static func evaluate(_ data: Data, password: String? = nil) -> ArchivalReadiness?
}
```
- Consumes: `QPDFService.withQPDF` (:304), `qpdf_is_encrypted` (qpdf-c.h:355), `qpdf_get_root`/`qpdf_get_trailer`, `qpdf_oh_has_key`/`qpdf_oh_get_key` (same idioms as `sanitized` :102–112 and `hasXMPMetadata` :124). `isTagged` via `arc_Catalog_IsTagged` under `pdfiumLock` (load the doc with `FPDF_LoadMemDocument`), OR the qpdf `/Root/MarkInfo /Marked` flag (prefer PDFium's catalog flag; fall back to qpdf if the load fails). **Reuse the private `hasKey` helper by extracting it** (or add a small local mirror) — do not duplicate silently.

- [ ] **Step 1: Failing tests** — one fixture per flag (commit tiny fixtures or synthesize):

```swift
final class ArchivalReadinessServiceTests: XCTestCase {
    func testEncryptedFlag() throws {
        let r = try XCTUnwrap(ArchivalReadinessService.evaluate(encryptedFixture(), password: "x"))
        XCTAssertTrue(r.isEncrypted)
    }
    func testJavaScriptFlagsActiveContent() throws {
        XCTAssertTrue(try XCTUnwrap(ArchivalReadinessService.evaluate(jsBearingFixture())).hasActiveContent)
    }
    func testTaggedFixtureIsTagged() throws {
        XCTAssertTrue(try XCTUnwrap(ArchivalReadinessService.evaluate(taggedFixture())).isTagged)   // reuse N2's fixture
    }
    func testCleanFixtureHasNoActiveContent() throws {
        XCTAssertFalse(try XCTUnwrap(ArchivalReadinessService.evaluate(cleanFixture())).hasActiveContent)
    }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** the binding + the four cheap flags (encrypted / active-content / XMP / tagged). **Step 4:** `swift build -c release` (binding added) + `swift test --filter ArchivalReadinessServiceTests`. **Step 5: Commit** — `feat: archival-readiness core flags (encryption/active-content/XMP/tagged) + IsTagged binding`.

**Gotchas:** `qpdf_is_encrypted` needs the doc opened; a password-protected member with no stored password → treat `isEncrypted = true` and mark downstream checks "unknown." `arc_Catalog_IsTagged` returns `FPDF_BOOL` (`Int32`, nonzero = true). Don't leak the PDFium doc handle — `FPDF_CloseDocument` under the lock. `hasActiveContent` = ANY of `/OpenAction`, `/AA` (root), `/Names/JavaScript` — exactly the keys `sanitized` strips (:103/:104/:107).

### Task M2: Fonts-embedded + OutputIntent checks (the meaty introspection)

**Files:** same as M1 (extend `ArchivalReadinessService`).

**Interfaces (append, private):**
```swift
// Walk every page's /Resources /Font; a font is "embedded" if its FontDescriptor has
// /FontFile | /FontFile2 | /FontFile3 (Type0 → recurse /DescendantFonts). Returns false on the
// first non-embedded font found.
static func allFontsEmbedded(_ qpdf: qpdf_data) -> Bool
static func hasOutputIntent(_ qpdf: qpdf_data) -> Bool   // /Root/OutputIntents non-empty array
```
- Consumes: `qpdf_oh_*` array/dict walk (`qpdf_oh_get_array_n_items`/`get_array_item`, `qpdf_oh_get_dict_keys`/`qpdf_oh_get_key`, `qpdf_oh_has_key`) — all already used in `QPDFService`'s AcroForm walk (:198–290). Pages via `qpdf_get_root` → `/Pages` → recurse `/Kids`, or `qpdf_oh_get_key(root,"/Pages")` tree.

- [ ] **Step 1: Failing tests** — an all-embedded fixture → `allFontsEmbedded == true`; a fixture with a non-embedded base-14 font reference (no FontFile) → `false`; a fixture with `/OutputIntents` → `hasOutputIntent == true`.

```swift
func testUnembeddedFontDetected() throws {
    XCTAssertFalse(try XCTUnwrap(ArchivalReadinessService.evaluate(unembeddedFontFixture())).allFontsEmbedded)
}
func testOutputIntentDetected() throws {
    XCTAssertTrue(try XCTUnwrap(ArchivalReadinessService.evaluate(outputIntentFixture())).hasOutputIntent)
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** the font walk (Type0 recursion into `/DescendantFonts` array → each CIDFont's `/FontDescriptor`; treat missing `/Font` dict on a page as "no fonts" = embedded-vacuously-true). `hasOutputIntent` = `/Root/OutputIntents` is an array with ≥ 1 item. **Step 4:** PASS + full `swift test`. **Step 5: Commit** — `feat: fonts-embedded + OutputIntent archival checks (font-descriptor walk)`.

**Gotchas:** don't be fooled by inherited resources — resources can live on `/Pages` (inherited) not just `/Page`; walk both. Standard-14 fonts (Helvetica etc.) legitimately have no FontFile — for PDF/A they must still be embedded, so "not embedded" is the correct *hint* even for base-14 (that is exactly what archival readiness flags). Cap page recursion depth. This is a *hint*, so false positives are acceptable and must be worded as such in M3.

### Task M3: "Archival readiness" checklist panel UI

**Files:**
- Create: `Orifold/Views/ArchivalReadinessView.swift`
- Modify: `Orifold/Views/ContentView.swift` (add a `MoreRoute` case + a More-menu row that presents the panel as a `.sheet` or popover, mirroring the existing route hand-off :640/:2992), OR add it as a lightweight section under the Info inspector tab (choose the More-menu sheet to keep the Inspector uncluttered)
- Test: none new (UI); relies on M1/M2 service tests

- [ ] **Step 1:** Panel: a checklist, one row per `ArchivalReadiness` field, each with a pass/warn glyph (`checkmark.seal` / `exclamationmark.triangle`) + a one-line hint. Header text: **"Archival readiness hints"** + subtitle "Quick signals for long-term archiving. This is not PDF/A validation." Every string via `L10n.string(forKey:locale:)`, view reads `@Environment(\.locale)`. Compute once on present (off the current member bytes); show a spinner while evaluating a large doc off the main actor.
- [ ] **Step 2:** `swift test`; **hands-on**: open an encrypted PDF → "Encrypted" warns; open a clean tagged all-embedded PDF → all green; confirm the panel never says "valid/compliant."
- [ ] **Step 3: Commit** — `feat: archival readiness hints panel`.

**Gotchas:** run `evaluate` off the main actor (`Task.detached`) — the font walk on a big doc can take a beat. Never present a single aggregate "PASS/FAIL" — it's a per-signal checklist by design.

### Task M4: L10n ×6 + hands-on

**Files:** Modify `Orifold/Resources/Localizable.xcstrings`; Test `LocalizationCoverageTests` + `RawLocalizationKeyLeakTests`.

- [ ] **Step 1:** Keys ×6: `archival.title` ("Archival readiness hints"), `archival.subtitle` ("Quick signals for long-term archiving — not PDF/A validation."), `archival.row.encryption` ("Not encrypted"), `archival.row.activeContent` ("No JavaScript or auto-actions"), `archival.row.fontsEmbedded` ("All fonts embedded"), `archival.row.outputIntent` ("Has an output intent (color)"), `archival.row.xmp` ("Has XMP metadata"), `archival.row.tagged` ("Tagged for accessibility"), `archival.menu.open` ("Archival readiness…"). Order-preserving. Coverage + RawLocalizationKeyLeak pass.
- [ ] **Step 2:** Full `swift test` + `swift build -c release`. **Step 3: Commit** — `feat: archival readiness localization (6 languages)`. Tick master Status row.

---

# Feature L — Offline translation  *(repo's FIRST `#available(macOS 15)` gate; zero new bindings)*

Design: pure `TranslationChunker` + a `TextTranslating` protocol (so tests use a fake — the real `TranslationSession` is not CI-testable) → gated `.translationTask` host + result panel → menu wiring + selection/page text source → honest disclosure sheet + L10n. **No write-back into the PDF in v1** — translation is a read-only side panel.

### Task L1: TranslationChunker (pure) + TextTranslating protocol + availability shim

**Files:**
- Create: `Orifold/Engine/Translation/TranslationSupport.swift`
- Test: `Tests/OrifoldTests/TranslationChunkerTests.swift`

**Interfaces:**
```swift
enum TranslationChunker {
    /// Splits text into request-sized chunks on sentence/paragraph boundaries, never mid-word.
    static func chunk(_ text: String, maxCharsPerRequest: Int = 4000) -> [String]
}
protocol TextTranslating {                       // protocol-wrap so tests inject a fake
    func translate(_ chunks: [String]) async throws -> [String]
}
struct TranslationRequestText: Equatable { let source: String; let chunks: [String] }
enum TranslationFeature {
    /// The single availability predicate the UI branches on (repo's first macOS-15 gate).
    static var isAvailable: Bool { if #available(macOS 15, *) { return true } else { return false } }
}
```

- [ ] **Step 1: Failing tests** (pure + deterministic — the real value):

```swift
final class TranslationChunkerTests: XCTestCase {
    func testShortTextIsOneChunk() {
        XCTAssertEqual(TranslationChunker.chunk("Hello world.", maxCharsPerRequest: 4000), ["Hello world."])
    }
    func testSplitsOnBoundaryNotMidWord() {
        let text = String(repeating: "Sentence one is here. ", count: 500)   // > 4000 chars
        let chunks = TranslationChunker.chunk(text, maxCharsPerRequest: 4000)
        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { $0.count <= 4000 })
        XCTAssertEqual(chunks.joined().replacingOccurrences(of: "", with: ""), text.trimmingCharacters(in: .whitespaces)) // no text lost
    }
    func testEmptyTextYieldsNoChunks() { XCTAssertTrue(TranslationChunker.chunk("").isEmpty) }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** chunking (accumulate sentences via `enumerateSubstrings(in:options:.bySentences)`; flush when adding the next sentence would exceed `maxCharsPerRequest`; a single over-long sentence splits on whitespace). `TranslationFeature.isAvailable` is the gate. **Step 4:** PASS. **Step 5: Commit** — `feat: translation text chunker + TextTranslating protocol + macOS-15 availability shim`.

**Gotchas:** keep this file free of `import Translation` (it must compile on the 14 floor) — only `TranslationFeature.isAvailable` references `#available`, no macOS-15 *types*. The chunker is where all the deterministic test value lives; the session itself is faked in L2's test.

### Task L2: Gated `.translationTask` host + result panel view

**Files:**
- Create: `Orifold/Views/TranslationPanelView.swift`
- Test: `Tests/OrifoldTests/TranslationPanelTests.swift` (drive the panel with a fake `TextTranslating`)

**Interfaces:**
```swift
@available(macOS 15, *)
struct SystemTranslator: TextTranslating {                 // real adapter, behind the gate
    let session: TranslationSession
    func translate(_ chunks: [String]) async throws -> [String] {
        try await session.translations(from: chunks.map { .init(sourceText: $0) }).map(\.targetText)
    }
}

struct TranslationPanelView: View {                        // host; owns original/translated state
    let sourceText: String
    // ...
    // Behind `if #available(macOS 15, *)`: a hidden child view carries `.translationTask(configuration)`
    // and constructs SystemTranslator(session:) inside the action closure, feeding TranslationChunker
    // output through it, then publishing results back up.
}
```

- [ ] **Step 1: Failing test** — inject a fake `TextTranslating` (reverses each chunk) into the panel's view-model layer; assert the translated column equals the fake's output for chunked input; assert that below macOS 15 (`TranslationFeature.isAvailable == false` simulated via the protocol path) the panel shows the "requires macOS 15" state. Since `.translationTask` can't run in CI, test the **view-model** that sits between the panel and `TextTranslating`, not SwiftUI itself.

```swift
final class TranslationPanelTests: XCTestCase {
    struct ReversingFake: TextTranslating {
        func translate(_ chunks: [String]) async throws -> [String] { chunks.map { String($0.reversed()) } }
    }
    func testViewModelTranslatesViaProtocol() async throws {
        let vm = TranslationPanelModel(source: "abc. def.", translator: ReversingFake())
        try await vm.run()
        XCTAssertFalse(vm.translated.isEmpty)
        XCTAssertEqual(vm.translated, TranslationChunker.chunk("abc. def.").map { String($0.reversed()) }.joined())
    }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** `TranslationPanelModel` (source → `TranslationChunker.chunk` → `translator.translate` → join), the SwiftUI panel (side-by-side original/translated, a target-language picker bound to `TranslationSession.Configuration`, a Copy button), and the `@available(macOS 15, *)` `.translationTask` wiring that builds `SystemTranslator`. **Step 4:** `swift test` + `swift build` (14 floor must still compile). **Step 5: Commit** — `feat: gated translation panel + system-translator adapter`.

**Gotchas (from the verified API):** you **cannot** instantiate `TranslationSession` — it is handed to you by `.translationTask(configuration)`. **Never store the session** in a long-lived model (`WorkspaceViewModel`) — it's tied to the view that may present system download/permission UI. Re-run by mutating the `Configuration` (set to `nil` then a new value) — the modifier re-fires. `import Translation` only inside `@available(macOS 15, *)` scopes.

### Task L3: Menu wiring + selection/page text source

**Files:**
- Modify: `Orifold/Views/ContentView.swift` (add a `MoreRoute.translate` case :3033; a More-menu row **hidden when `!TranslationFeature.isAvailable`**; present `TranslationPanelView` via the existing route hand-off :640/:2992), `Orifold/ViewModels/WorkspaceViewModel.swift` (add `var translationSourceText: String` deriving from `currentSelection` text if non-empty, else the current page's `attributedString?.string` — mirror :3829)
- Test: `Tests/OrifoldTests/TranslationPanelTests.swift` (source-selection logic)

- [ ] **Step 1:** Failing test on the source-picker: with a non-empty selection → source = selection text; with no selection → source = current-page text (CI-safe: build the expectation from `attributedString`, gotcha (d)). **Step 2:** Implement. Menu row: "Translate selection…" / "Translate page…" (label reflects whether a selection exists), gated by `#available`/`TranslationFeature.isAvailable`. **Step 3:** `swift test`. **Step 4: Commit** — `feat: translate menu entry + selection/page text source (gated)`.

**Gotchas:** on macOS 14 the menu row must be **absent** (not just disabled) — cleanest first-gate example. Reach `pdfView.currentSelection` through the existing selection plumbing (`currentSelectionPageRefs` :2711 / the ReadingCanvas coordinator), don't add a second selection observer.

### Task L4: Disclosure sheet + L10n ×6 + hands-on

**Files:** Modify `Orifold/Views/TranslationPanelView.swift` (first-use disclosure), `Orifold/Resources/Localizable.xcstrings`; Test `LocalizationCoverageTests` + `RawLocalizationKeyLeakTests`.

- [ ] **Step 1:** First-use disclosure sheet (persist "seen" in `UserDefaults`). **Honest wording — do NOT claim "nothing leaves your Mac" unconditionally**, because the first use of a language triggers an OS model download from Apple:
  - `translation.disclosure.title` = "About offline translation"
  - `translation.disclosure.body` = "Translation runs on your Mac using Apple's built-in Translation service. The first time you use a language, macOS may download that language to your Mac from Apple — that download is a macOS system service, not Orifold. Your document text is translated on-device and is not sent to Orifold."
  - plus `translation.menu.selection` ("Translate selection…"), `translation.menu.page` ("Translate page…"), `translation.panel.original` ("Original"), `translation.panel.translated` ("Translation"), `translation.copy` ("Copy translation"), `translation.targetLanguage` ("Translate to"), `translation.unavailable` ("Requires macOS 15 or later.").
  - All ×6, order-preserving. Coverage + RawLocalizationKeyLeak pass.
- [ ] **Step 2:** Full `swift test` + `swift build` (14) + the CI Xcode-16.4 build path if reproducible locally; **hands-on on a macOS 15+ machine**: select text → Translate → panel shows translation, disclosure appears first run, Copy works; **hands-on on macOS 14 (or simulate)**: the menu row is absent. **Step 3: Commit** — `feat: translation disclosure + localization (6 languages)`. Tick master Status row.

**Gotchas:** the disclosure must be truthful about the OS model download (Apple's Translate models are OS-managed, downloaded on demand) — this is the whole point of the honest-wording requirement. Keep it factual, not scary.

---

# Feature P — CBZ → PDF import  *(NEW SPM dependency: ZIPFoundation, MIT)*

Design: add ZIPFoundation (both manifests + `xcodegen`) and a `CBZReader` (list/extract images, natural-sorted, in-memory, zip-bomb-guarded) → `CBZImportService` (images → merged PDF via the existing lane) → import wiring (UTType `.cbz`, Info.plist doc type, `importFiles` route) → L10n. Read-only archive use; sandbox-fine.

### Task P1: Add ZIPFoundation + CBZReader (list/extract, natural sort, size guards)

**Files:**
- Modify: `Package.swift` (deps :16 → add `.package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0"))`; target deps :26 → add `.product(name: "ZIPFoundation", package: "ZIPFoundation")`), `project.yml` (`packages:` :31 → `ZIPFoundation: {url: https://github.com/weichsel/ZIPFoundation.git, majorVersion: 0.9.0}`; target `dependencies:` :58 → `- package: ZIPFoundation`), then `xcodegen generate`; `Package.resolved` (commit updated), `Orifold/Resources/THIRD-PARTY-NOTICES.md` (ZIPFoundation MIT entry)
- Create: `Orifold/Engine/CBZ/CBZReader.swift`
- Test: `Tests/OrifoldTests/CBZReaderTests.swift`

**Interfaces:**
```swift
struct CBZEntry: Equatable { let name: String; let byteCount: Int }
enum CBZImportError: LocalizedError { case unreadableArchive, noImages, entryTooLarge, totalTooLarge }
enum CBZReader {
    static let maxEntryBytes = 64 * 1024 * 1024        // per-image cap (zip-bomb guard)
    static let maxTotalBytes = 512 * 1024 * 1024       // whole-archive uncompressed cap
    static func imageEntryNames(in data: Data) throws -> [String]     // natural-sorted, image ext only
    static func extractImage(_ name: String, from data: Data) throws -> Data
}
```
- Consumes: ZIPFoundation `Archive(data: data, accessMode: .read)`; `Archive` conforms to `Sequence` → iterate `Entry`; filter by image extension (`png/jpg/jpeg/gif/tif/tiff/webp/bmp/heic`); natural sort via `localizedStandardCompare` (precedent `FolderImportScanner.swift:66`). Extract via the `Consumer` closure (`archive.extract(entry) { chunk in data.append(chunk) }`) accumulating `Data` — no temp files.

- [ ] **Step 1: Failing tests** — commit a tiny fixture `Tests/OrifoldTests/Fixtures/three-pages.cbz` (3 PNGs named `page1.png`,`page2.png`,`page10.png`) + a corrupt `.cbz` (truncated zip):

```swift
final class CBZReaderTests: XCTestCase {
    func testListsImagesInNaturalOrder() throws {
        XCTAssertEqual(try CBZReader.imageEntryNames(in: cbzFixture()), ["page1.png", "page2.png", "page10.png"])  // NOT page1,page10,page2
    }
    func testExtractReturnsImageBytes() throws {
        let bytes = try CBZReader.extractImage("page1.png", from: cbzFixture())
        XCTAssertNotNil(NSImage(data: bytes))
    }
    func testCorruptArchiveThrowsLocalized() {
        XCTAssertThrowsError(try CBZReader.imageEntryNames(in: corruptFixture())) {
            XCTAssertNotNil(($0 as? CBZImportError)?.errorDescription)     // LocalizedError surfaced
        }
    }
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement.** Guard total uncompressed size (sum of `entry.uncompressedSize`) ≤ `maxTotalBytes` before extracting; skip non-image + directory entries + macOS `__MACOSX/` cruft + dotfiles. **Step 4:** `swift build` (proves the dependency resolves in SPM) + `swift test --filter CBZReaderTests`. **Step 5: Commit** — `feat: add ZIPFoundation; CBZ archive reader (natural sort + zip-bomb guard)`.

**Gotchas:** **ZIPFoundation API-shape caveat** — recent versions (0.9.16+) made `Archive(data:accessMode:)` a **throwing** initializer (older ones were failable/`init?`). Pin `from: "0.9.0"` but write the call site to match whatever `Package.resolved` actually resolves (`try Archive(...)` for current 0.9.20) — grep the resolved version and adapt; a mismatched init signature is the most likely compile break. Sandbox: reading a user-selected `.cbz` in memory needs only the existing `user-selected.read-write` entitlement (present). Enforce the size caps **before** allocating extraction buffers.

### Task P2: CBZImportService — images → merged PDF

**Files:**
- Create: `Orifold/Engine/CBZ/CBZImportService.swift`
- Modify: `Orifold/Engine/PDFKitEngine.swift` (widen `renderImage(_:title:)` :1031 from `private static` to `static`, OR add a `static func pageDocument(from image: NSImage)` sibling reusing `ImagePDFPageView`)
- Test: `Tests/OrifoldTests/CBZReaderTests.swift` (append) / new `CBZImportServiceTests`

**Interfaces:**
```swift
enum CBZImportService {
    static func pdf(from cbz: Data, title: String) throws -> PDFDocument
}
```
- Consumes: `CBZReader.imageEntryNames` + `extractImage`; for each image build a one-page PDF via the widened `renderImage` (or `ImagePDFPageView`), then merge into one `PDFDocument` with the `output.insert(page, at: output.pageCount)` pattern (precedent `PDFKitEngine.swift:1057/:1083`).

- [ ] **Step 1: Failing test** — 3-image fixture → 3-page PDF, correct order (CI-safe: assert `pageCount == 3` and per-page **thumbnail brightness** differs if pages are distinguishable, gotcha (d); never `PDFPage.string`). Empty-of-images `.cbz` → `CBZImportError.noImages`.

```swift
func testCBZBecomesThreePagePDF() throws {
    let doc = try CBZImportService.pdf(from: cbzFixture(), title: "Comic")
    XCTAssertEqual(doc.pageCount, 3)
}
```

- [ ] **Step 2:** FAIL. **Step 3: Implement** (loop images → merge). **Step 4:** full `swift test`. **Step 5: Commit** — `feat: CBZ→PDF conversion (images merged in natural order)`.

**Gotchas:** preserve order from `CBZReader` (already natural-sorted) — do NOT re-sort by extraction completion. Large comics: this rasters each page into a PDF page (no text layer — that's expected for a comic). Keep the page-size logic consistent with `renderImage` (612×792 with margin) or fit-to-image; decide once and note it in the UI (P3). This is a **fresh** PDF (no preserved-text concern; the preserving pipeline doesn't apply).

### Task P3: Import wiring — UTType + Info.plist doc type + importFiles route

**Files:**
- Modify: `Orifold/Document/WorkspaceDocument.swift` (add `static let orifoldCBZ = UTType(filenameExtension: "cbz") ?? UTType(importedAs: "com.ud.cbz")` near :6–20), `project.yml` (`CFBundleDocumentTypes` :75–115 → add a `cbz` viewer entry, e.g. `CFBundleTypeExtensions: [cbz]`, `LSItemContentTypes: [public.zip-archive]`), then `xcodegen generate`, `Orifold/Engine/PDFKitEngine.swift` or `WorkspaceViewModel.importFiles(urls:)` :789 (route `.cbz`/`com.ud.cbz` → `CBZImportService.pdf(from:title:)` → an `ImportedDocument`)
- Test: `Tests/OrifoldTests/CBZReaderTests.swift` (route recognizes the extension)

- [ ] **Step 1:** Failing test — the import type-detection path maps a `.cbz` URL/type to the CBZ lane (assert the produced `PDFDocument` page count, or that `CBZImportService` is invoked). **Step 2:** Implement the route in the same place image/PDF types are branched (`PDFKitEngine` :447/:488 conforms-to checks). **Step 3:** `swift test`; regenerate the Xcode project (`xcodegen generate`) and confirm it builds under the Xcode path too. **Step 4: Commit** — `feat: register .cbz import type + route to CBZ importer`.

**Gotchas:** `.cbz` is a renamed `.zip` → `UTType(filenameExtension:"cbz")` may resolve to `public.zip-archive` or be unknown; declare an `importedAs` fallback so detection is deterministic. Make sure the new doc type doesn't shadow the existing "Structured Package Document" zip family (:96–100) — CBZ is a distinct extension. Add `cbz` only as a **Viewer** role.

### Task P4: L10n ×6 + hands-on

**Files:** Modify `Orifold/Resources/Localizable.xcstrings`; Test `LocalizationCoverageTests` + `RawLocalizationKeyLeakTests`.

- [ ] **Step 1:** Keys ×6: `import.cbz.progress` ("Importing comic…"), `import.cbz.error.unreadable` ("This comic archive couldn't be read."), `import.cbz.error.noImages` ("No images found in this comic archive."), `import.cbz.error.tooLarge` ("This comic archive is too large to import."). Wire these as the `LocalizedError.errorDescription` values for `CBZImportError` (via `L10n.string`). Order-preserving. Coverage + RawLocalizationKeyLeak pass.
- [ ] **Step 2:** Full `swift test`; **hands-on**: File → Open a real `.cbz` → pages import in order; open a corrupt `.cbz` → localized error, no crash. **Step 3: Commit** — `feat: CBZ import localization (6 languages)`. Tick master Status row.

---

# Feature O — CJK font pack (+ mandatory embedding spike)  *(SPIKE-GATED — do LAST)*

> **⚠️ SPIKE GATE + CROSS-WAVE DEPENDENCY.** O1 (the spike) **gates** O2/O3. And O's brief says "Reuse Wave 2's `FontRegistrar`" — **`FontRegistrar` does NOT exist on this branch** (Wave 2 unshipped; verified grep empty). If Wave 2 has not landed when O runs, O1 must self-provide minimal process-scope font registration (`CTFontManagerRegisterFontsForURL(.process)`) and O2's display-substitution path must bundle Shippori Mincho itself. **Medium confidence.**

Design: **spike FIRST (O1)** — bind `FPDFText_LoadFont`, embed a large CJK font into an edited PDF, measure exported-byte bloat. **Then, conditional on the result:** O2-A (no bloat → optional Noto GitHub-Release pack + embed) OR O2-B (bloat → display-only substitution + export warning). O3 = L10n + hands-on for whichever path shipped.

### Task O1: Embedding spike — `FPDFText_LoadFont` binding + measure export bloat  *(THE GATE)*

**Files:**
- Create: `Orifold/Engine/Fonts/CJKFontSpikeBindings.swift` (the binding), `Tests/OrifoldTests/CJKEmbeddingSpikeTests.swift`
- (Spike may also reuse `poe_InsertObjectAtIndex` :100, `poe_GenerateContent` :105, and bind `FPDFPageObj_CreateTextObj` + `FPDFText_SetText` if placing real text — one binding per symbol, `cjk_` prefix.)

**Interfaces:**
```swift
// fpdf_edit.h:1348 — FPDF_FONT FPDFText_LoadFont(FPDF_DOCUMENT, const uint8_t*, uint32_t, int, FPDF_BOOL).
@_silgen_name("FPDFText_LoadFont")
func cjk_Text_LoadFont(_ doc: OpaquePointer?, _ data: UnsafePointer<UInt8>?, _ size: UInt32, _ fontType: Int32, _ cid: Int32) -> OpaquePointer?
// FPDF_FONT_TYPE1 = 1, FPDF_FONT_TRUETYPE = 2 (fpdf_edit.h). CID = 1 for CJK.
```

- [ ] **Step 1: The spike IS the test** (roadmap gotcha). Load a real large CJK TTF (Noto Sans JP full, ~16–17 MB, fetched into a *test-only, git-ignored* path — NOT bundled) via `cjk_Text_LoadFont(cid:1)`, create a text object with a few CJK glyphs, insert it, `poe_GenerateContent`, save via the reused `FPDFCompression_SaveAsCopy` (PDFCompressionService :80), and **measure the exported byte delta** vs the identical doc using a standard font. Assert-and-record:

```swift
func testMeasureCJKEmbeddingBloat() throws {
    let baseline = try exportedBytesWithStandardFont()
    let embedded = try exportedBytesWithLoadedCJKFont(notoSansJPURL())    // skip test if the TTF isn't present
    let deltaMB = Double(embedded.count - baseline.count) / 1_048_576
    print("CJK embed delta = \(deltaMB) MB")
    XCTAssertTrue(QPDFService.isStructurallySound(embedded))
    // DECISION RECORD (not a hard bound): deltaMB <= 3 → PDFium subsets → O2-A viable.
    //                                     deltaMB  > 3 → no subsetting → O2-B (display-only).
}
```

- [ ] **Step 2:** FAIL (unbound). **Step 3:** Implement the binding(s) + spike. **Step 4:** `swift build -c release` (binding) + run; **record the measured delta in the commit message and in `docs/OPEN_SOURCE_FEATURE_ROADMAP.md` item #10.** **Step 5: Commit** — `spike: measure PDFium CJK font embedding bloat (gates Feature O scope) — delta=<X>MB`.

**Decision:** if delta ≤ ~3 MB/doc (PDFium subsets) → proceed **O2-A**. If delta is many MB (full font embedded, no subsetting) → **STOP embedding**, proceed **O2-B** (display-only substitution + export warning, Wave 2's 4D posture). Either way O ships *something*; the spike only decides which.

**Gotchas:** `font_type` = 2 (TrueType), `cid` = 1 for CJK. `FPDFText_LoadFont` copies the font data into the doc — the returned `FPDF_FONT` is owned by the doc. Do NOT bundle the 16–17 MB test TTF; fetch it to a git-ignored fixtures dir and `XCTSkip` if absent (CI won't have it — the spike is a dev-machine measurement, its *decision* is recorded in docs, not re-run in CI). Release-build after the binding.

### Task O2 *(CONDITIONAL on O1)*: ship the chosen path

**Path O2-A — optional Noto pack + embed (only if O1 delta ≤ ~3 MB):**
- **Files:** reuse the update-channel download pattern (`Orifold/Engine/Updates/*`) for an **optional GitHub-Release** font pack (~25–40 MB — NOT in the DMG; DMG is ~15 MB, gotcha in roadmap #10); create `Orifold/Engine/Fonts/CJKFontPack.swift` (download + checksum-verify + license-file check + register via `CTFontManagerRegisterFontsForURL(.process)`); wire `cjk_Text_LoadFont` into the editor's export path for CJK-using edited text.
- **Tests:** pack manifest verify (checksum + bundled license), substitution-table entries for common JP/SC PDF font names (`MS-Mincho`, `MSMincho`, `SimSun`, `Hiragino*`, `YuMincho`, `MS-Gothic` → bundled Noto/Shippori), embed round-trip stays `isStructurallySound` and delta matches the spike.

**Path O2-B — display-only substitution + export warning (if O1 shows bloat):**
- **Files:** `Orifold/Engine/Fonts/CJKSubstitution.swift` — map common JP/SC PDF font names → the bundled Shippori Mincho (display/editor only, **no embedding**); on export of a doc whose edited text used a substituted CJK font, surface a one-time warning ("CJK glyphs are shown with a substitute font and are not embedded on export"). If Wave 2's `FontRegistrar` exists, reuse it; else register Shippori here.
- **Tests:** substitution mapping (subset-tag + style strip, mirror Wave 2's `FontSubstitution` if present); editor renders CJK via Shippori (assert `CTFontCopyPostScriptName` ≈ Shippori, gotcha (d)); export-warning fires exactly when a substituted CJK font was used.

- [ ] **Steps:** Standard red→green→refactor for the chosen path; `swift build -c release` (if any binding touched); commit `feat: CJK font pack (embedding)` **or** `feat: CJK display substitution + export warning` per the spike verdict.

**Gotchas:** if bundling Shippori for O2-B and Wave 2 didn't ship it, add the TTF to **both** manifests (gotcha (f)) + a THIRD-PARTY-NOTICES OFL entry. The optional Noto pack (O2-A) must ship its OFL license file inside the downloaded pack and verify it on install. Never bundle Noto in the DMG (size).

### Task O3 *(CONDITIONAL on O1)*: L10n ×6 + hands-on

**Files:** Modify `Orifold/Resources/Localizable.xcstrings`; Test `LocalizationCoverageTests` + `RawLocalizationKeyLeakTests`.

- [ ] **Step 1:** Keys ×6 for whichever path shipped — O2-A: `cjkPack.title`, `cjkPack.download`, `cjkPack.installed`, `cjkPack.verifyFailed`; O2-B: `cjk.substitution.note` ("CJK text is shown with a substitute font."), `cjk.export.warning` ("CJK glyphs won't be embedded in the exported PDF."). Order-preserving. Coverage + RawLocalizationKeyLeak pass.
- [ ] **Step 2:** Full `swift test` + `swift build -c release`; **hands-on**: edit CJK text → renders correctly; export → (A) glyphs embedded / (B) warning shown. **Step 3: Commit** — `feat: CJK font pack localization (6 languages)`. Tick master Status row + update roadmap #10 with the shipped scope.

---

## Wave 4 close-out

- [ ] Bump version (from `0.8.14`/build `20` — coordinate with whatever `project.yml`/`Package.swift` say at wave end) + write `docs/release-vX.Y.Z.md` in the existing format. Note the DMG-size delta (P adds ZIPFoundation ~small; O adds nothing to the DMG if O2-B or optional-pack).
- [ ] `swift build -c release` (silgen/WMO — **N, M, O add bindings**) + full `swift test`.
- [ ] `xcodegen generate` and confirm the **Xcode/CI path** builds too (P changed both manifests; the dual-manifest + `packages:` addition is the highest-risk CI break this wave).
- [ ] Delete stale local `Orifold.app` copies (`mdfind` sweep), install fresh, click through N/M/L/P and whichever O path shipped. Feature L's hands-on **requires a macOS 15+ machine**; also confirm the menu row is **absent** on 14.
- [ ] Tick Wave 4 rows in `docs/FEATURE_WAVES_MASTER_PLAN.md` Status table. Refresh `docs/OPEN_SOURCE_FEATURE_ROADMAP.md` items #3/#10/#13/#14/#16 with findings (esp. #10 with the O1 spike delta and shipped scope).
- [ ] **Note the cross-wave dependency in the Status table:** Feature O assumed Wave 2's `FontRegistrar`/Shippori; if Wave 2 hadn't shipped, record what O self-provided.
- [ ] Hold pushes (recovery branch) unless instructed.

## Confidence + spike/risk summary

| Feature | Confidence | New `@_silgen_name` | Spike/Blocked |
|---|---|---|---|
| L — Offline translation | **High** | 0 | repo's first `#available(macOS 15)` gate |
| M — Archival readiness hints | **Med-High** | 1 (`FPDFCatalog_IsTagged`) | — |
| N — Structure inspector | **Med-High** | 9 (`FPDF_StructTree_*`/`StructElement_*`) | — |
| O — CJK font pack | **Medium** | ≥1 (`FPDFText_LoadFont`) | **SPIKE-GATED (O1 gates O2/O3)** + Wave 2 `FontRegistrar` dependency unmet on this branch |
| P — CBZ import | **Med-High** | 0 | **new SPM dependency: ZIPFoundation (MIT)** |

## Sources (external facts verified)

- Apple Translation framework: [TranslationSession | Apple Developer](https://developer.apple.com/documentation/translation/translationsession), [Meet the Translation API — WWDC24](https://developer.apple.com/videos/play/wwdc2024/10117/) — macOS 15.0+/iOS 18+, third-party-capable, SwiftUI-only via `.translationTask` (session cannot be instantiated or stored in a long-lived model), on-device OS-managed models with on-demand download.
- ZIPFoundation: [github.com/weichsel/ZIPFoundation](https://github.com/weichsel/ZIPFoundation) — v0.9.20 (2025-09-24), **MIT**, macOS 10.11+, in-memory `Archive(data:accessMode:.read)` (throwing init in current versions), `Archive: Sequence`, `extract` via `Consumer` closure.
- PDFium symbols: verified by `nm -gU` on `Packages`→`.build/artifacts/pdfiumbinary/PDFium/PDFium.xcframework/macos-arm64_x86_64/PDFium.framework/PDFium` — `FPDFCatalog_IsTagged`, all `FPDF_StructTree_*`/`FPDF_StructElement_*`, `FPDFText_LoadFont` all exported; signatures read from the vendored `Headers/fpdf_catalog.h`, `fpdf_structtree.h`, `fpdf_edit.h`.
- CI toolchain: `.github/workflows/ci.yml` — `runs-on: macos-15`, `DEVELOPER_DIR=/Applications/Xcode_16.4.app` (macOS 15 SDK compiles Feature L behind `#available`; macOS 26 APIs absent — out of scope).
