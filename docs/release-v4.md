# pdFold release-v4 Release Notes

## GitHub Release Fields

Tag: `release-v4`

Target: commit tagged by `release-v4`

Release title: `pdFold release-v4 - bulletproof inline PDF text editing`

Asset to upload: `pdFold.zip`

Build the asset with:

```zsh
./scripts/install-mac.sh --package-only --package /tmp/pdFold.zip
```

## Release Notes

# Bulletproof Inline PDF Text Editing and PDF Save Metadata

**Release:** Latest release  
**Release date:** July 1, 2026  
**Tag:** [`release-v4`](https://github.com/udhawan97/PDFold/releases/tag/release-v4)

---

## ✦ A More Precise Native PDF Editor

pdFold release-v4 focuses on the text-editing path that matters most in dense real-world PDFs: click existing text, edit it in place, and export a PDF that keeps the original page stable.

The local-first document workspace, installer, automatic update flow, clean uninstall command, PDFium validation, and multi-format export from v3 remain intact. Version 4 hardens inline PDF text editing, PDF save metadata, release automation, and regression coverage so the app behaves more like a serious Mac PDF workflow tool.

This is primarily a **PDF editing fidelity, export integrity, and release automation release**.

---

## What's New in release-v4

### Bulletproof Inline PDF Text Editing

Inline PDF text editing now keeps document-space and screen-space measurements separate.

- The floating editor previews text at `documentFontSize * PDFView.scaleFactor`, so small 8-10pt resume text remains legible at fit-to-page zoom.
- Commits store document-space font size and a concrete PostScript font name instead of a zoomed display size.
- The editor listens for `PDFViewScaleChanged` while open and refreshes layout/formatting as the user zooms.
- Existing replacement alignment is preserved when reopening a previous edit.

---

### Shared CoreText Measurement and Rendering

Preview geometry, committed bounds, and PDF rendering now use one CoreText-based layout path for replacement text.

- Replacement measurement and drawing are unified through `ReplacementTextLayout`.
- Long replacements and unbreakable words expand predictably instead of clipping.
- The live editor's committed page-space bounds are honored instead of being re-pinned to the original source line.
- Repeated edits update the existing operation instead of stacking patches.

---

### Safer Erase and Page Regeneration

Text replacement now erases less and preserves more.

- The erase patch targets the original source text bounds, not `sourceBounds ∪ editedBounds`.
- The renderer samples the local page background instead of always painting white.
- Regeneration still starts from pristine original page bytes so repeated edits do not accumulate old patches.
- Existing highlight, note, ink, signature, and text-box annotations survive text edit regeneration.

---

### Better Font and Size Fidelity

PDFium-reported font sizes are now checked against actual glyph ink in page space.

- Scaled content streams no longer inflate replacement text by trusting nominal `Tf` sizes blindly.
- Carlito/Calibri-style embedded font names map to closer installed macOS faces when the exact source face is not available.
- Toolbar font, size, bold, italic, color, and alignment choices round-trip through preview, commit, export, save, and reopen.

---

### Undo, Redo, and Save Integrity

Inline PDF text edits now restore both rendered bytes and edit metadata.

- Undo restores prior PDF bytes and page edit state.
- Redo replays the edited PDF bytes and operation state.
- Save-as-PDF and `.pdfold` package snapshots continue to export from copied pages, preserving the live page-sharing invariant.
- App metadata is bumped to `CFBundleShortVersionString` `3.0` and `CFBundleVersion` `4`.

---

### Release and CI/CD Hardening

release-v4 also tightens the release path.

- `release-v*` tags now trigger the release workflow.
- Tagged releases publish `pdFold.zip` and are marked as the latest GitHub release.
- Rolling `pdFold-latest` builds still refresh from `main`, but no longer steal the latest-release pointer from versioned releases.
- README download links point at `https://github.com/udhawan97/PDFold/releases/latest/download/pdFold.zip`.

---

## Install

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/PDFold/main/install.sh | zsh
```

The installer downloads the latest `pdFold.zip`, installs `pdFold.app` to `~/Applications`, creates Desktop commands for launch/update and uninstall, clears quarantine metadata, and opens pdFold.

Direct download: [`pdFold.zip`](https://github.com/udhawan97/PDFold/releases/latest/download/pdFold.zip)

---

## Update

After installing release-v4, double-click `pdFold.command` on the Desktop. It checks the latest release before opening the app.

---

## Uninstall

Double-click `Uninstall pdFold.command` on the Desktop.

To keep pdFold app support, preferences, caches, and sandbox data:

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/PDFold/main/scripts/uninstall-mac.sh | zsh -s -- --keep-user-data
```

---

## Verification

```zsh
plutil -lint PDFold/Resources/Info.plist
plutil -lint PDFold/Resources/PDFold.entitlements
zsh -n install.sh
zsh -n scripts/install-mac.sh
zsh -n scripts/uninstall-mac.sh
zsh -n scripts/install-mac.command
zsh -n "Install or Update pdFold.command"
zsh -n "Uninstall pdFold.command"
plutil -lint "Install or Update pdFold.app/Contents/Info.plist"
swift build
swift test
./scripts/install-mac.sh --package-only --package /tmp/pdFold.zip
```

---

## Git Summary

Feature range used for this release summary: `release-v3..e467b45`

Summary:

```text
20 commits changed 36 files, with 2082 insertions and 543 deletions.
```

Commits:

- `e467b45` Bump app build for PDF save metadata
- `6847e79` Inline text editing overhaul
- `0dbbc21` Remove workspace save format from app bundle
- `f385452` Edit text bug fixes
- `5d8c859` Default saves to PDF
- `fdda0f1` Edit text bug fix
- `551a597` Update README.md
- `78467cc` Install script UI fix
- `1697764` Annotation on install script
- `768d6d9` Split same-baseline columns into separate editable blocks
- `0fdb103` Fix inline text edit placement and font-size fidelity
- `8088ac7` App name changes
- `9a4ec5b` Fix inline text editing: lost edits on export, misplaced/overlapping replacement text, dropped annotations, and font fidelity
- `fd596f7` Adding fixes for notes feature
- `d82cef0` renaming app to pdFold
- `955fe43` Shell script fixes
- `d609234` CI fixes
- `b43c6c7` Fix text edits not appearing live or after export
- `575348a` Fix inline text editing correctness and accumulation bugs
- `a7a2ee8` Editing feature retry

---

## Release Checklist

- Confirm `PDFold/Resources/Info.plist` is `3.0` / `4`.
- Confirm `project.yml` is `3.0` / `4`.
- Run the verification commands above.
- Confirm the `release-v4` tag points at the intended release commit locally and on `origin`.
- Confirm the GitHub release for `release-v4` is marked latest and contains `pdFold.zip`.
