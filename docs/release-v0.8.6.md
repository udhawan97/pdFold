# v0.8.6 Orifold

## GitHub Release Fields

Tag: `v0.8.6`

Target: latest commit tagged by `v0.8.6`

Release title: `v0.8.6 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.6-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.6-macOS-universal.dmg.sha256` — checksum sidecar (also what the in-app updater verifies against)
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `v*` / `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, runs the packaged-app smoke gate, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.6
```

## Release Notes

# v0.8.6 Orifold

**Release:** Latest release
**Tag:** [`v0.8.6`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.6)

---

## What Changed Since v0.8.5

v0.8.5 gave Orifold the ability to **notice** a new version. v0.8.6 lets it **download and verify** that version from inside the app, protect your open work, and hand off cleanly to the installer. No document-editing behavior changes this cycle.

### Added: in-app download + verified install hand-off

- **Download inside the app.** When an update is available, the Settings → Updates row now offers **Download Update**. Orifold fetches the signed, versioned universal DMG directly into its own updater cache directory, with a live progress bar.
- **Verified before it can install.** The download is checked against the release's published `.sha256` checksum sidecar. A file whose hash doesn't match is deleted and surfaced as a verification failure — a truncated or tampered download can never reach the install step, and your current version is left untouched.
- **Unsaved-work protection.** Before the install hand-off, Orifold checks for open documents with unsaved changes and asks you to save them first, so no work is lost.
- **A sandbox-honest hand-off.** A sandboxed app cannot replace its own running bundle, so Orifold opens the verified disk image's drag-to-Applications window for you to finish the install. Consent-first throughout — nothing downloads or installs unless you ask, and automatic checks remain off by default.
- **Self-cleaning updater cache.** Stale downloaded artifacts and superseded rollback copies are pruned automatically at launch. Cleanup is structurally scoped to Orifold's own updater directories and can never touch your PDFs, recent files, preferences, or recovery snapshots.

### Fixed

- **Settings update-status no longer overflows.** The "update available" row previously bled past the edge of the fixed-width Settings window. It now lays out vertically and wraps, and every update state (checking, downloading, ready, failed) is Reduce-Motion aware.

### Under the hood

- New, fully unit-tested pieces: an SHA-256-verifying downloader (including a checksum-mismatch rejection test), a safe updater-artifact cleaner (proven never to delete user files), and an unsaved-work preflight. A three-round bug/crash audit hardened the download flow against a continuation hang and a stale-progress race. Full test suite: 650 tests.

## Install / Upgrade

1. Download `Orifold-0.8.6-macOS-universal.dmg` (or the stable-name `Orifold.dmg`).
2. Open it and drag **Orifold** into **Applications**.
3. Launch from Applications. Existing users on v0.8.5 will be offered v0.8.6 by the in-app updater, or can re-run `scripts/install-mac.sh`, which always fetches the latest release.
