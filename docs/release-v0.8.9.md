# v0.8.9 Orifold

## GitHub Release Fields

Tag: `v0.8.9`

Target: latest commit tagged by `v0.8.9`

Release title: `v0.8.9 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.9-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.9-macOS-universal.dmg.sha256` — checksum sidecar (also what the in-app updater verifies against)
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `v*` / `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, runs the packaged-app smoke gate, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.9
```

## Release Notes

# v0.8.9 Orifold

**Release:** Latest release
**Tag:** [`v0.8.9`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.9)

---

## What Changed Since v0.8.8

A bug-fix patch for the Select tool (object editing) that shipped in v0.8.8. No new features — three rounds of a dedicated UI-bug audit turned up 16 real issues, all fixed and covered by new regression tests. Nothing else in the app changed this cycle.

### Fixed: selection no longer gets lost or stuck

- Rotating, deleting, or duplicating an **unrelated** page no longer clears your current object selection.
- Rotating the selected object's own page (which still can't be edited while rotated) now correctly **brings your selection back** if you undo the rotation.
- Deleting the page under a selected object no longer leaves a dangling selection that swallows the next <kbd>Delete</kbd> key press.
- <kbd>Esc</kbd> now deselects an object, matching every other transient selection in the app.

### Fixed: resize correctness

- Resizing an object whose graphic is internally rotated or skewed (a tilted image placed on an otherwise upright page) no longer shears it — it now moves normally and holds its size, instead of resizing into a distorted shape.
- Resize handles no longer silently stop responding at extreme zoom levels.

### Fixed: data-safety (the important ones)

- **Object edits no longer get silently corrupted or reverted** by deleting, duplicating, or reordering pages in the same document afterward — previously, an unrelated later edit could quietly undo those structural changes or apply an edit to the wrong page.
- Running **Make Searchable (OCR)** on a document that already had object edits no longer risks stripping the newly added text layer on the next edit.
- Clicking to select an object right after deleting, duplicating, or reordering pages no longer reads a stale, wrong page structure.

### Fixed: polish

- The Select tool's toolbar label no longer duplicates the annotation-selection tool's "Select" label (now "Edit Objects") — was ambiguous for VoiceOver users.
- The Edit menu's Undo/Redo items now name the specific action ("Undo Move Object") instead of a bare "Undo".
- The object-selection tooltip now uses neutral blue styling instead of alarming yellow warning styling.

### Under the hood

- `OrderSnapshot` (the undo/redo mechanism shared by page delete/duplicate/reorder/OCR) now round-trips the object-editing lane's frozen base and pending operations, not just the text-editing lane's — closing a gap where those operations could silently desync from the restored bytes.
- A new `refreezeObjectBaseIfStale` keeps the object-edit regeneration base in sync with any structural page change in the same member, so a later edit never regenerates from stale, pre-change bytes.
- 8 new regression tests (24 total for object editing); full suite (703 tests) run green twice locally plus CI.

## Install / Upgrade

1. Download `Orifold-0.8.9-macOS-universal.dmg` (or the stable-name `Orifold.dmg`).
2. Open it and drag **Orifold** into **Applications**.
3. Launch from Applications. Existing users will be offered v0.8.9 by the in-app updater, or can re-run `scripts/install-mac.sh`, which always fetches the latest release.
