# v0.9.1 Orifold

## GitHub Release Fields

Tag: `v0.9.1`

Target: latest commit tagged by `v0.9.1`

Release title: `v0.9.1 Orifold — Nothing waits in silence`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.9.1-macOS-universal.dmg` — drag-to-Applications disk image for Apple Silicon and Intel
- `Orifold-0.9.1-macOS-universal.dmg.sha256` — checksum sidecar used by the in-app updater
- `Orifold.dmg` — byte-identical stable-name alias for `releases/latest/download/Orifold.dmg`
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, minimum macOS, and architecture
- `Orifold.zip` — one-line installer, Homebrew cask, and Desktop-helper artifact

Automation: `.github/workflows/release.yml` builds a universal app when a `v*` / `release-v*` tag is pushed, packages and smoke-tests the DMG, publishes the tagged release as GitHub's latest release, and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --clean --no-open --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --output /tmp/Orifold-0.9.1-macOS-universal.dmg --version 0.9.1
```

## Release Notes

# v0.9.1 Orifold — Nothing waits in silence

**Release:** Latest release

**Tag:** [`v0.9.1`](https://github.com/udhawan97/Orifold/releases/tag/v0.9.1)

---

## What Changed Since v0.9.0

A user-flow release. Every one of these came from an audit that walked Orifold's seven main journeys — first run and import, reading and search, page editing, annotation and signing, export, the inspectors, and settings — looking specifically for moments where the app knew something and did not say it.

### The app no longer goes quiet under load

- **Export stays responsive, and can be canceled.** Protecting, sanitizing, or imposing a PDF used to run the whole pipeline on the main thread with no progress and no way out — the window simply stopped responding until it finished. Those exports now run with the same progress indicator and working Cancel that file-size reduction and signing already had, and they name the stage they are on.
- **Export asks where to save first.** The file was previously assembled, imposed, sanitized, and encrypted *before* the save panel appeared, so cancelling the panel threw all of that work away. The destination is chosen first; nothing is computed for an export you decided not to keep.
- **Search no longer says "No results" while it is still searching.** The panel shows a searching state until a scan completes, and the scan itself no longer blocks the window on a long document.

### The app says what it is doing

- **Every search match is highlighted**, not just the one you are standing on, with the active match still distinct.
- **The match counter survives closing the search panel.** A small "N of M" chip stays in the bottom bar with next, previous, and clear, so ⌘G is no longer navigating blind.
- **Stamps, hanko seals, and barcodes announce themselves.** Choosing one now shows a banner saying it is waiting for a page click, Escape cancels it, and leaving the tool disarms it. Previously it waited invisibly and could land on a page you clicked minutes later.
- **Read Aloud explains its silence.** On a scanned page with no text layer it now says there is nothing to read and points at OCR, instead of doing nothing at all.
- **The zoom level is visible**, and clicking it returns you to actual size.
- **The Contents list says when an outline was truncated** rather than quietly ending early on a very large document.
- **Folder imports report what actually arrived.** The summary — including the VoiceOver announcement — used to fire before any file had been parsed, with the count that was attempted. It now waits for the import and reports the real number.

### Password-protected files stop being treated as damaged

- **Double-clicking a locked PDF explains itself.** Opening one from Finder or File ▸ Open used to fail with a generic macOS error; Orifold now gives the same clear explanation the in-app import path always gave. The same applies to corrupt, oversized, and empty files.
- **Open Recent on a locked PDF prompts for the password** instead of dead-ending in an alert.
- **An encrypted PDF is no longer called "damaged."** It gets its own message, because an encrypted file is intact and opens fine once the password is known.

### Guidance where there was only a verdict

- **Archival readiness tells you what to do.** Each failing signal now carries a remediation sentence, and says plainly when Orifold cannot fix it — tagging, output intent, embedded fonts, and XMP metadata all have to come from the app that produced the PDF.
- **The Structure tab shows a missing-alt-text total** without needing every branch expanded.
- **The Info tab names the document it edits.** In a multi-file workspace it always edits the first file's properties — the ones a merged export keeps — which was true before and invisible before.
- **Un-applied metadata typing survives.** Switching inspector tabs, clicking another file's page, or undoing no longer silently discards what you had typed but not applied.

### Protection and language

- **Export passwords have a minimum length** of 8 characters, with a non-blocking hint when an accepted password is still easy to guess. AES-256 previously accepted a single character without comment.
- **Window titles follow the app language.** The About and Software Update titles updated only after a relaunch. The notification that was supposed to handle this had no observers at all and has been removed.

## Privacy and Compatibility

- Nothing here adds a network call. Every change is local, and export processing remains on-device.
- Orifold still requires macOS 14 Sonoma or newer and ships as one universal Apple Silicon + Intel build.
- No workspace schema migration is required. Existing PDFs and workspaces continue to open normally.

## Important Boundaries

- Archival readiness is still guidance, not PDF/A certification or conversion — the new hints make that boundary explicit rather than moving it.
- Structure inspection remains read-only; the alt-text total reports the problem, it does not fix it.
- The export minimum-length rule applies to new exports; it does not re-evaluate the password on a file protected by an earlier version.
- `saveFlattenedPDF(to:)` with an explicit destination stays synchronous for scripted callers; the asynchronous path is the interactive one.

## Verification

- 974 tests gate the source release, including twelve new regressions covering export-stage cancellation, the split export pipeline, password-protected import classification, armed-placement cancellation and disarm-on-tool-change, the searching state, and metadata-draft preservation.
- The release build and SwiftLint are clean, and the app was installed to `~/Applications/Orifold.app` and driven through search, zoom, and match navigation on the real surface.
- Verified in the running app: all matches highlight simultaneously, the zoom percentage tracks the live scale, and the match counter persists after the search popover closes.
