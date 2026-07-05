# v7 Orifold

## GitHub Release Fields

Tag: `release-v7`

Target: latest commit tagged by `release-v7`

Release title: `v7 Orifold`

Asset to upload: `Orifold.zip`

Automation: `.github/workflows/sync-release-v7.yml` checks `origin/main` every 30 minutes, moves `release-v7` only when `main` has advanced, and then dispatches the release workflow to rebuild the latest v7 asset.

Build the asset with:

```zsh
./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
```

## Release Notes

# v7 Orifold

**Release:** Latest release
**Release date:** July 5, 2026
**Tag:** [`release-v7`](https://github.com/udhawan97/Orifold/releases/tag/release-v7)

---

## A Bulletproof PDF Engine Underneath

Orifold v7 adds a native, dependency-light [qpdf](https://github.com/qpdf/qpdf) engine (Apache-2.0, statically linked, vendored as a universal `arm64`/`x86_64` library — no external process, no network call) alongside PDFKit and PDFium. It powers four things: repairing corrupt PDFs on import, real AES-256 password protection, a lossless structural compression pass, and a "sanitize for sharing" export option — all gated by a qpdf structural check that now runs before every export leaves the app.

Everything from v6 still works: local-first workspace, one-line installer, searchable OCR, forms, stamps, decorations, compression, protected export, and multi-format export. Version 7 started as a **durability and trust release** for the engine underneath, and grew over the cycle into the everyday reading experience, the landing screen, and a long, deliberate pass of hardening on inline text editing — the release's earlier bug fixes are covered below alongside the qpdf work.

---

## What's New in v7

### Corrupt PDFs Get Repaired, Not Rejected

Files with damaged cross-reference tables or malformed object structures used to fail on import. Orifold now falls back to qpdf's recovery path when PDFKit can't open a file.

- qpdf reconstructs the cross-reference table and repairs damaged objects before Orifold retries the import.
- Recovery is silent when it succeeds — the user just sees their file open.
- Covered by import-stress tests that feed deliberately corrupted PDFs through the real import pipeline.

### Real AES-256 Password Protection

Protected export previously used CoreGraphics' 128-bit RC4/AES path. It now goes through qpdf's R6 encryption handler.

- User and owner passwords, plus print/copy permissions, are set through qpdf's AES-256 (PDF 2.0) encryption parameters.
- Post-export verification still reopens and unlocks the result before handing it back, matching v6's guarantee.

### Sanitize for Sharing

A new export option strips content designed to run automatically or leak information you didn't mean to send.

- Removes catalog-level auto-run actions (`/OpenAction`), embedded JavaScript, and embedded files.
- An opt-in sub-toggle also strips document metadata (author, producer, timestamps).
- Sanitize is now applied consistently on every export path, including the compressed-export path — a gap found and fixed during this release's audit (see below).
- If sanitization can't be completed, export now fails loudly with a clear message instead of silently shipping an unsanitized file.

### Lossless Structural Compression

The existing image-downsampling compression pass is now followed by a qpdf object-stream optimization pass.

- Repacks the PDF's internal object structure losslessly — this catches size wins that image downsampling alone can't, especially on text-heavy PDFs.
- Runs after image compression and before sanitize/encryption in the export pipeline, so gains compound instead of being undone.

### Every Export Is Structurally Validated

Previously, plain unencrypted exports had no post-write validation at all. Every PDF Orifold writes — encrypted or not — now passes a qpdf structural check (`qpdf --check`-equivalent) before it's allowed to reach disk.

---

## A More Comfortable Way to Read

Reader Mode and Night Mode are new. Reader Mode hides text editing and signing tools behind one toggle, leaving only the study tools (highlight, search, notes) active — useful for reviewing a document without the risk of nudging its content. Night Mode moved from a single fixed dark tint to three presets — **Gentle**, **Paper**, and **Amber** — each an independently tuned mix of warmth, intensity, and dimming, so a late read doesn't mean picking between "too blue" and "too dark."

---

## Landing Screen and Visual Refresh

The empty-state landing screen's animated fold mark went through several passes this cycle before settling on a detailed, richly shaded origami crane (an elegant swan variant was tried and shelved in favor of the crane, which better echoes the app icon). Along the way: the fold now replays on tap, autoplays once after a short delay, and hands off seamlessly into the real app icon; a reported animation-jank issue was traced to redundant per-frame layer and compute work and fixed.

The rest of the app also picked up a quieter, warmer visual identity — new palette tokens use washi-paper neutrals and a *shu-iro* (hanko-seal) vermillion accent for signing and stamping, with calmer typography spacing throughout. Two long-standing UI bugs were fixed alongside it: **About Orifold** previously lived in a Commands-menu popover with no visible anchor, so it silently never opened — it now opens in a proper window; and the Guide popover's feature grid was redesigned with clearer gradient icon tiles and card surfaces.

---

## Hardening That Happened Along the Way

This release went through an explicit audit pass — one reviewer for user-flow/logic bugs, one adversarial pass hunting crashes and memory-safety issues in the new native engine integration — before merging. What it found and fixed:

- **Sanitize was silently skipped on the compressed-export path.** Checking "Reduce file size" and "Sanitize for sharing" together in the export sheet produced a smaller file that was *not* actually sanitized, with no warning. Fixed by threading the sanitize option through the compression pipeline and making sanitize failures throw instead of silently falling back.
- **A missing signature-conflict guard** on the compressed-export path could let sanitize/encryption options through even when the workspace has a placed digital signature. Fixed to match the guard already used on the plain export path.
- **An undo/redo crash** was found and fixed independently during release verification (see `Orifold/App/AppCommands.swift`, `Orifold/ViewModels/WorkspaceViewModel.swift`).
- The new qpdf C API wrapper (`Orifold/Engine/QPDFService.swift`) was reviewed for pointer-lifetime and concurrency safety; no exploitable issues were found, though two low-severity robustness notes were logged for future hardening (an unnecessarily conservative 2 GB import-size guard, and undocumented reliance on Swift `Data`'s retain behavior across a C API boundary).

### Inline Text Editing: A Long Run of Root-Cause Fixes

Inline PDF text editing got sustained, repeated attention this cycle — real-world import compatibility, geometry, undo, and formatting-fidelity bugs, each traced to a root cause rather than patched around:

- **Right-margin bleed:** a wrapped paragraph's detected column used the page edge instead of its own right margin, so edited text could re-wrap past where the original text stopped.
- **Font-size drift on stacked paragraphs:** the merge tolerance for "is this line part of the same paragraph" was computed from the whole in-progress paragraph's height instead of one line's height, so a paragraph that had already merged several lines could silently absorb the next paragraph below it — editing the first then visibly shifted the second's position and size.
- **Import-compatibility audit** across every supported format (native/scanned/OCR'd PDFs, rotated/cropped pages, forms, signatures, RTFD/XLSX/PPTX/EPUB/Markdown/HTML/RTF): found and fixed a rotated-page background blanking bug, added a warning before an edit could silently invalidate a third-party-signed PDF's signature, and made silent-flatten-to-plain-text failures on non-PDF exports fail loudly instead, matching existing DOCX/ODT/RTF behavior.
- **Match/Copy/Restore could reapply the wrong formatting** on a reopened edit, because the lookup keyed off a per-run-generated block ID instead of a stored original. Fixed by preserving the true original formatting on the edit operation itself.
- **Font-size detection was measurably off** (5-12%, font-dependent) because it estimated point size from ink height using one fixed ratio for every font; fixed by deriving the ratio from each font's own cap-height/descender metrics.
- **Ten further passes** landed together: majority-run (not first-glyph) color/font detection, a silent text-truncation fix near the page's bottom margin, a growth-strip blank-check to stop replacement text drawing over adjacent images, per-edit (not per-batch) undo grouping, and fixing the inline editor overlay's position drifting on scroll.
- Toolbar polish rode along: clearer Match/Copy/Paste/Reset icons, a redo shortcut fix (⌘⇧Z had been routed to undo), and reachability fixes so the Delete/Cancel/Done group stays visible with the inspector open.

Test count grew with the fixes, from 281 to 320 as this work landed.

---

## Install

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/Orifold/main/install.sh | zsh
```

The installer downloads the latest `Orifold.zip`, installs `Orifold.app` to `~/Applications`, creates Desktop commands for launch/update and uninstall, clears quarantine metadata, and opens Orifold.

Direct download: [`Orifold.zip`](https://github.com/udhawan97/Orifold/releases/latest/download/Orifold.zip)

Homebrew users can install the same prebuilt release app:

```zsh
brew tap udhawan97/orifold https://github.com/udhawan97/Orifold
brew install --cask udhawan97/orifold/orifold
```

The cask clears download quarantine after installation, matching the one-line installer. Release builds are fully Gatekeeper-trusted once the release workflow is configured with Apple Developer ID signing and notarization secrets.

---

## Update

After installing v7, double-click `Orifold.command` on the Desktop. It checks the latest release before opening the app.

---

## Uninstall

Double-click `Uninstall Orifold.command` on the Desktop.

To keep Orifold app support, preferences, caches, and sandbox data:

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/Orifold/main/scripts/uninstall-mac.sh | zsh -s -- --keep-user-data
```

---

<details>
<summary>Developer details</summary>

### New Dependency

`Packages/QPDFBinary` vendors a universal (`arm64` + `x86_64`) static build of [qpdf](https://github.com/qpdf/qpdf) 12.3.0 (Apache-2.0) plus [libjpeg-turbo](https://github.com/libjpeg-turbo/libjpeg-turbo) 3.1.0 (BSD/IJG/zlib, a mandatory qpdf build dependency), built with qpdf's native crypto provider so there is no external OpenSSL/GnuTLS dependency. The binary is committed directly to the repo as a local `.xcframework` binary target, following the same SPM pattern as `Packages/PDFiumBinary`. See `Orifold/Resources/THIRD-PARTY-NOTICES.md` for license text.

### Verification

```zsh
plutil -lint Orifold/Resources/Info.plist
plutil -lint Orifold/Resources/Orifold.entitlements
zsh -n install.sh
zsh -n scripts/install-mac.sh
zsh -n scripts/uninstall-mac.sh
zsh -n scripts/install-mac.command
zsh -n "Install or Update Orifold.command"
zsh -n "Uninstall Orifold.command"
zsh -n "Install or Update Orifold.app/Contents/MacOS/OrifoldInstaller"
plutil -lint "Install or Update Orifold.app/Contents/Info.plist"
swift build
swift test
xcodebuild build -quiet -project Orifold.xcodeproj -scheme Orifold -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -quiet -project Orifold.xcodeproj -scheme Orifold -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
```

All of the above passed cleanly when this release was first gated on the qpdf engine work (July 4): 281 tests, 0 failures; the packaged app was unpacked and confirmed to launch, report `CFBundleShortVersionString v7`, and have qpdf symbols statically linked into the executable. The suite was re-run after the later reading-experience, landing-screen, and inline-text-editing hardening passes (July 5): `swift test` — 320 tests, 0 failures, 8 skipped.

### Git Summary

Feature range used for the product-change summary: `release-v6..HEAD`

Summary:

```text
123 files changed, 19091 insertions(+), 1061 deletions(-)
```

Commits (newest first):

- `27b47d6` Fix animation jank in the crane fold: cut per-frame layer/compute overhead
- `120b5bd` Ten hardening passes on inline text editing
- `d4e8d56` Add subtle Japanese-inspired theme flair; fix unreachable About window; polish Guide popover with Apple-style icon tiles
- `4d0829b` Redesign landing fold as a detailed origami crane with richer Apple-style shading
- `eee757c` Deepen swan fold shading to match app icon contrast
- `bfe15c2` Redesign landing fold as an elegant origami swan, richer choreography
- `2c24b66` Fix font-size inaccuracy causing Match/Copy to not preserve original size
- `b2eb6ce` Sweep stray Orifold.app copies from /Applications before install
- `6635941` Redesign landing fold into a detailed shaded origami crane; add matching README logo
- `e8866a6` Adding more in-text validations
- `664d1aa` Bug squish
- `b60bbf6` Add reader and night mode enhancements
- `45ea6ea` Fold the landing mark into an origami crane; fix stale-window autoplay
- `bb084cf` Redesign README hero + value-props SVGs in the architecture-diagram theme with animation
- `f264b10` Fix landing fold: autoplay after 1s + seamless icon hand-off
- `5a608b0` Fix wrapped-paragraph over-merge causing font-size/position drift on edit
- `d0d216e` Harden inline text editing against real-world import compatibility gaps
- `5bf203c` Make the landing-screen fold mark replay on tap
- `769725a` Add animated origami-fold intro to the landing screen
- `44fc78d` Uninstall script and readme updates
- `8b982ae` Fix inline PDF text-edit bleed, toolbar reach, undo/redo, export safety
- `4f291bc` Harden PDF import and drop flows
- `51c5b40` Clarify inline text-edit toolbar icons and tooltips
- `27e7ad8` prep for v7 bug fix w engines
- `6e131b7` Add v7 release notes and sync workflow
- `496e708` Update README and architecture diagrams for v7 qpdf engine
- `f797768` Fix inline text edit Match/Copy/Restore not recovering true original formatting
- `b33a8ff` Fixing undo crash
- `b9ec21e` Add qpdf engine: repair, real AES-256 encryption, sanitize, export validation

Notable files:

- `Orifold/Engine/QPDFService.swift`
- `Orifold/Engine/PDFKitEngine.swift`
- `Orifold/Engine/PDFEncryptionService.swift`
- `Orifold/Engine/PDFCompressionService.swift`
- `Orifold/Engine/PDFTextAnalysisEngine.swift`
- `Orifold/Engine/PDFEditedPageRenderer.swift`
- `Orifold/Models/WorkspaceExportOptions.swift`
- `Orifold/Models/NightModeSettings.swift`
- `Orifold/ViewModels/WorkspaceViewModel.swift`
- `Orifold/Views/ContentView.swift`
- `Orifold/Views/OrifoldFoldMark.swift`
- `Orifold/Views/GuidePopover.swift`
- `Orifold/DesignSystem/DesignSystem.swift`
- `Orifold/App/AppCommands.swift`
- `Packages/QPDFBinary/Package.swift`
- `Tests/OrifoldTests/QPDFServiceTests.swift`
- `Tests/OrifoldTests/ImportStressTests.swift`
- `docs/assets/orifold-crane-fold.svg`
- `docs/assets/orifold-v3-architecture-diagram.svg`

### Release Checklist

- Confirm `Orifold/Resources/Info.plist` is `v7` / `7`.
- Confirm `project.yml` is `v7` / `7`.
- Run the verification commands above.
- Confirm the `release-v7` tag points at `origin/main` locally and on `origin`.
- Confirm the GitHub release for `release-v7` is marked latest and contains `Orifold.zip`.

</details>
