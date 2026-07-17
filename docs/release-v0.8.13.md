# v0.8.13 Orifold

## GitHub Release Fields

Tag: `v0.8.13`

Target: latest commit tagged by `v0.8.13`

Release title: `v0.8.13 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.13-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.13-macOS-universal.dmg.sha256` — checksum sidecar used by the in-app updater
- `Orifold.dmg` — byte-identical stable-name alias for `releases/latest/download/Orifold.dmg`
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, minimum macOS, and architecture
- `Orifold.zip` — used by the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app when a `v*` / `release-v*` tag is pushed, packages the DMG, smoke-tests the packaged app, publishes the tagged release as GitHub's latest release, and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --clean --no-open --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --output /tmp/Orifold-0.8.13-macOS-universal.dmg --version 0.8.13
```

## Release Notes

# v0.8.13 Orifold

**Release:** Latest release
**Tag:** [`v0.8.13`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.13)

---

## What Changed Since v0.8.12

This hotfix corrects editor controls that could become abbreviated or clipped after a live canvas resize. It also fixes the same intrinsic-width error in localized note and text-box editor actions. No document-format, editing-engine, privacy, or network behavior changes.

### Fixed

- **Readable inline editing controls.** Match, Copy, Paste, Reset, Cancel, and Done now use AppKit's actual configured-button size, including bezel and icon space, instead of estimating from glyph width and guessed padding.
- **Reliable panel and window resizing.** The toolbar retains fully readable labels when the canvas narrows after the inline editor is already open.
- **Localized note-editor actions.** Cancel and Done now fit their shipped Spanish, French, Hindi, Japanese, and Simplified Chinese titles; the previous fixed Cancel width clipped Spanish, French, and Japanese.

### Verified

- Added red-to-green regression coverage for the exact live-resize failure and every shipped note-editor locale.
- Rechecked inline editing, format actions, object editing, interaction transitions, page operations, undo/redo, source-format export, PDF export, save, and reopen flows.
- The release gate contains 751 tests across 186 Swift app-and-test files, plus production build, generated-project, documentation, packaging, and installed-app checks.

## Install / Upgrade

1. Download `Orifold-0.8.13-macOS-universal.dmg` or the stable-name `Orifold.dmg`.
2. Open it and drag **Orifold** into Applications.
3. Launch from Applications. Existing users can also use Orifold's consent-based updater or rerun `scripts/install-mac.sh`, which fetches the latest release.
