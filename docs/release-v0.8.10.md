# v0.8.10 Orifold

## GitHub Release Fields

Tag: `v0.8.10`

Target: latest commit tagged by `v0.8.10`

Release title: `v0.8.10 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.10-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.10-macOS-universal.dmg.sha256` — checksum sidecar (also what the in-app updater verifies against)
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `v*` / `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, runs the packaged-app smoke gate, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.10
```

## Release Notes

# v0.8.10 Orifold

**Release:** Latest release
**Tag:** [`v0.8.10`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.10)

---

## What Changed Since v0.8.9

A bug-fix patch for the Select tool (object editing). No new features. This round came from actually **driving the app by hand** — opening a PDF, selecting a shape, and moving/deleting it — which surfaced two real bugs that the byte-level test suite structurally couldn't catch. Both are fixed and covered by a new regression test.

### Fixed

- **Moved and deleted objects now update on screen immediately.** Previously, moving or deleting a page object changed the file correctly under the hood — the edit was real, the saved/exported file was right — but the canvas kept showing the object in its old place until you scrolled or switched pages. The view now refreshes the moment you drop or delete, so what you see always matches what's in the file.
- **Object edits can now be undone.** After moving, resizing, or deleting an object, **Undo** (⌘Z, the toolbar button, and the Edit menu) stayed greyed out — the edit was registered internally but the controls weren't wired to see it. Undo/Redo now light up right after an object edit and revert it cleanly, with the correct label ("Undo Move Object", "Undo Delete Object", and so on). A related internal fix removes a stray empty undo step that could otherwise swallow the first ⌘Z.

### Under the hood

- The canvas now swaps in the freshly regenerated page document after an object commit (matching how every other edit already refreshes), instead of just repainting the stale one.
- The Undo/Redo controls read the view model's own undo manager — the one every edit registers on — and re-evaluate after AppKit-driven canvas commits, rather than an environment undo manager that was `nil` in the menu scene.
- Object-edit undo actions are now named inside their undo group, eliminating a spurious empty group.
- Full suite: 704 tests, CI green (SwiftPM + Xcode lanes), including a new regression test that asserts an object commit enables Undo on the manager the UI reads and reverts it.

## Install / Upgrade

1. Download `Orifold-0.8.10-macOS-universal.dmg` (or the stable-name `Orifold.dmg`).
2. Open it and drag **Orifold** into **Applications**.
3. Launch from Applications. Existing users will be offered v0.8.10 by the in-app updater, or can re-run `scripts/install-mac.sh`, which always fetches the latest release.
