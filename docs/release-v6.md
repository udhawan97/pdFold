# v6 pdFold

## GitHub Release Fields

Tag: `release-v6`

Target: latest commit tagged by `release-v6`

Release title: `v6 pdFold`

Asset to upload: `pdFold.zip`

Build the asset with:

```zsh
./scripts/install-mac.sh --package-only --package /tmp/pdFold.zip
```

## Release Notes

# v6 pdFold

**Release:** Latest release candidate  
**Release date:** July 2, 2026  
**Tag:** [`release-v6`](https://github.com/udhawan97/PDFold/releases/tag/release-v6)

---

## A Bigger Local PDF Finishing Workflow

pdFold v6 turns the app into a more complete Mac-first PDF workspace. You can still import scattered files, organize pages, comment, annotate, sign, save, and export. The new release adds the finishing tools people usually need right before sending a document: searchable scans, form handling, stamps, watermarks, page numbers, Bates labels, compression, and password-protected PDF export.

The important part is the same as before: the work stays local. pdFold uses the Mac's native PDF and OCR tooling plus local PDF validation instead of sending documents to a remote service.

## Install

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/PDFold/main/install.sh | zsh
```

Direct download: [`pdFold.zip`](https://github.com/udhawan97/PDFold/releases/latest/download/pdFold.zip)

The installer downloads the latest `pdFold.zip`, installs `pdFold.app` to `~/Applications`, creates Desktop commands for launch/update and uninstall, clears quarantine metadata, and opens pdFold.

Homebrew users can install the same prebuilt release app:

```zsh
brew tap udhawan97/pdfold https://github.com/udhawan97/PDFold
brew install --cask udhawan97/pdfold/pdfold
```

---

## What's New

| Area | What changed | Why it helps |
| --- | --- | --- |
| Searchable scans | Local OCR can add invisible text to scanned pages | Scanned PDFs become searchable without uploading documents |
| Forms | pdFold detects form fields, shows form status, supports reset, and can lock answers during export | Forms can be completed and sent as final PDFs |
| Stamps and decorations | Watermarks, page numbers, Bates labels, and movable stamps can be added and burned into export | Legal, review, and packet-prep workflows need fewer outside tools |
| Protected export | Final PDFs can be password-protected and verified after export | Sensitive documents are easier to share deliberately |
| Compression | Oversized PDFs can be downsampled and validated | Large image-heavy files become easier to send |
| Export integrity | Form flattening, decoration baking, compression, encryption, and validation share a stricter export path | The exported PDF better matches what the user expects |
| UI polish | Empty state, annotation toolbar, page indicator, sidebar metrics, search width, and comment actions were cleaned up | The app feels calmer during repeated document work |

## Update

After installing v6, double-click `pdFold.command` on the Desktop. It checks the latest release before opening the app.

## Uninstall

Double-click `Uninstall pdFold.command` on the Desktop.

To keep pdFold app support, preferences, caches, and sandbox data:

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/PDFold/main/scripts/uninstall-mac.sh | zsh -s -- --keep-user-data
```

---

<details>
<summary>Developer details</summary>

### Verification

```zsh
plutil -lint PDFold/Resources/Info.plist
plutil -lint PDFold/Resources/PDFold.entitlements
zsh -n install.sh
zsh -n scripts/install-mac.sh
zsh -n scripts/uninstall-mac.sh
zsh -n scripts/install-mac.command
zsh -n "Install or Update pdFold.command"
zsh -n "Uninstall pdFold.command"
zsh -n "Install or Update pdFold.app/Contents/MacOS/pdFoldInstaller"
plutil -lint "Install or Update pdFold.app/Contents/Info.plist"
swift build
swift test
xcodebuild build -quiet -project PDFold.xcodeproj -scheme PDFold -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -quiet -project PDFold.xcodeproj -scheme PDFold -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
./scripts/install-mac.sh --package-only --package /tmp/pdFold.zip
```

### Git Summary

Feature range used for the product-change summary: `release-v5..HEAD`

Summary:

```text
18 commits changed 30 files, with 8150 insertions and 509 deletions.
```

Commits:

- `374457b` More bug fixes
- `646be7a` Prevent sidebar metric truncation
- `1dff4d5` Redesign empty-state background and annotation toolbar
- `bfdf1db` More UI bug fix
- `3c732c1` Polish page indicator control
- `093e096` Fixing animation and broken comment button
- `4daf848` Add V6 final verification gate
- `bbfffee` Working towards new features
- `8c47c65` Audit findings +
- `754506e` Add protected PDF export
- `95fe5c0` Audit loop closed
- `194324f` Audit loop changes
- `db8f03b` Commenting + audit fixes +
- `9889608` Comment text box fix
- `b92e9a6` Search box width change
- `3edf250` Use SwiftPM for CodeQL analysis
- `df38a08` Speed up CodeQL analysis build
- `69b18b4` Intro UI change

Notable files:

- `PDFold/Engine/PDFOCRService.swift`
- `PDFold/Engine/PDFCompressionService.swift`
- `PDFold/Engine/PDFEncryptionService.swift`
- `PDFold/Engine/PDFFormSupport.swift`
- `PDFold/Engine/PDFDecorationExportBaker.swift`
- `PDFold/Models/WorkspaceExportOptions.swift`
- `PDFold/Models/PageDecoration.swift`
- `PDFold/ViewModels/WorkspaceViewModel.swift`
- `PDFold/Views/ReadingCanvas.swift`
- `PDFold/Views/InspectorView.swift`
- `PDFold/Views/StampPalette.swift`
- `Tests/PDFoldTests/PDFOCRTests.swift`
- `Tests/PDFoldTests/PDFoldTests.swift`
- `Tests/PDFoldTests/SourceDocumentRoundTripTests.swift`
- `docs/features/V6_VERIFICATION.md`

### Release Checklist

- Confirm `PDFold/Resources/Info.plist` is `3.0` / `6`.
- Confirm `project.yml` is `3.0` / `6`.
- Run the verification commands above.
- Confirm the `release-v6` tag points at the intended release commit locally and on `origin`.
- Confirm the GitHub release for `release-v6` is marked latest and contains `pdFold.zip`.

</details>
