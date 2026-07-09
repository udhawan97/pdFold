# v0.8.8 Orifold

## GitHub Release Fields

Tag: `v0.8.8`

Target: latest commit tagged by `v0.8.8`

Release title: `v0.8.8 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.8-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.8-macOS-universal.dmg.sha256` — checksum sidecar (also what the in-app updater verifies against)
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `v*` / `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, runs the packaged-app smoke gate, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.8
```

## Release Notes

# v0.8.8 Orifold

**Release:** Latest release
**Tag:** [`v0.8.8`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.8)

---

## What Changed Since v0.8.7

v0.8.8 makes the object-editing engine that landed dormant in v0.8.7 **usable**: a new **Select** tool lets you edit the real graphics on a page.

### Added: object editing (beta)

- **A new Select tool.** Next to Edit Text in the toolbar. Click a real graphic on the page — an image, a logo, a line, a shape — and a selection outline with handles appears.
- **Move, resize, delete.** Drag to move, drag a handle to resize, press <kbd>Delete</kbd> (or the red button) to remove. The page updates immediately, with full undo/redo (<kbd>⌘Z</kbd> / <kbd>⌘Y</kbd>).
- **Real edits, no ghosts.** Changes are written into the file's actual page content — a moved image really moves, a deleted shape is really gone — with no leftover copy and no leaked ink. They survive **save, reopen, and export**, and render correctly in other PDF viewers.
- **Honest about what it can't do.** Orifold tells you what you've selected and what's possible: images/logos/lines/simple shapes are editable; reused graphics edit one copy at a time; scanned or flattened pages are one image; gradients are shown for reference. It never silently does nothing.

### Known limits this cycle (still growing)

- **No mixing with text edits on the same document yet.** If a document already has inline text edits, the Select tool asks you to finish or undo them first (and vice versa). This is a deliberate guard so neither kind of edit can overwrite the other — not a silent failure.
- **Rotated pages** aren't editable yet (the object stays selectable but can't be moved).
- **Duplicate, recolor, layering (bring forward / send backward), and multi-select** are next.

### Under the hood

- New engine `PDFObjectEditEngine` performs the edit by mutating the page's real objects via PDFium (`SetMatrix` / `RemoveObject`) and regenerating the content stream — leak-free and ghost-free by construction, with a mandatory color-preservation pass (from the v0.8.7 Phase-0 finding) so redrawn shapes keep their fill. A shared object-identity digest lets an edit re-bind to its object across every save/reload. Every commit is a single undoable step that restores member bytes byte-exactly.
- Verified by a permanent test suite (object round-trip, VM commit/undo/redo, export→reopen with no ghost) and a four-pass adversarial review that found and fixed a same-object transform+delete bug, a cross-lane data-loss path (now guarded), and several selection-lifecycle bugs before release. Full suite: 695 tests, CI green (SwiftPM + Xcode lanes).

## Install / Upgrade

1. Download `Orifold-0.8.8-macOS-universal.dmg` (or the stable-name `Orifold.dmg`).
2. Open it and drag **Orifold** into **Applications**.
3. Launch from Applications. Existing users on v0.8.7 will be offered v0.8.8 by the in-app updater, or can re-run `scripts/install-mac.sh`, which always fetches the latest release.
