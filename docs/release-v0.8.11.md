# v0.8.11 Orifold

## GitHub Release Fields

Tag: `v0.8.11`

Target: latest commit tagged by `v0.8.11`

Release title: `v0.8.11 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.11-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.11-macOS-universal.dmg.sha256` — checksum sidecar (also what the in-app updater verifies against)
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `v*` / `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, runs the packaged-app smoke gate, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.11
```

## Release Notes

# v0.8.11 Orifold

**Release:** Latest release
**Tag:** [`v0.8.11`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.11)

---

## What Changed Since v0.8.10

Three additive improvements — a new object-editing control, a friendlier About window, and a real safety net for updates. No breaking changes.

### New

- **Layer objects: Bring to Front / Send to Back.** When you select a shape, line, or image with the Select tool, **right-click it** for a menu to move it above or behind the other objects on the page — plus Delete. It's a real content-stream reorder (the same leak-free engine that powers move/resize/delete), fully undoable, and it survives export. Rotated pages stay out of scope for now, same as the rest of object editing.
- **Restore Previous Version.** After the in-app updater installs an update, Orifold quietly keeps a verified copy of the version you were on. If a new build ever misbehaves, **Help → Restore Previous Version…** closes the app, swaps the old version back into place (checksum-verified, signature-verified), and reopens — your documents untouched. The menu item stays greyed out until there's actually something to roll back to. Power users can also run `scripts/install-mac.sh --restore <archive.zip>` from Terminal for the same result when the app itself won't launch.

### Improved

- **The About window now tells you where you stand on updates.** Open **Orifold → About Orifold** and, right under the version stamp, you'll see whether you're up to date or an update is waiting — one click opens the Software Update window to download and install.

### Under the hood

- Z-order is realized by the already-shipped `objectReorder` operation (PDFium `RemoveObject` + `InsertObjectAtIndex`), committed through the same `applyObjectEdit` path as every other object edit, with its own atomic undo step ("Bring Object to Front" / "Send Object to Back"). The canvas swaps in the regenerated page immediately, mirroring the v0.8.10 refresh fix.
- Restore reuses the update system's proven, dry-run-tested stage-then-swap contract, kept as a **separate** script template so the shipped update path is byte-for-byte unchanged. The archive is re-verified against its recorded SHA-256 before the app ever quits, and any failure mid-swap restores the current bundle.
- Every new user-facing string is localized across all six languages (English, Spanish, French, Hindi, Simplified Chinese, Japanese), enforced by the coverage and raw-key-leak guards.
- New tests: object z-order round-trip + undo; restore hand-off orchestration (including a checksum-mismatch abort); and a live dry-run that actually swaps a signed bundle from an archived zip and relaunches.

## Install / Upgrade

1. Download `Orifold-0.8.11-macOS-universal.dmg` (or the stable-name `Orifold.dmg`).
2. Open it and drag **Orifold** into **Applications**.
3. Launch from Applications. Existing users will be offered v0.8.11 by the in-app updater, or can re-run `scripts/install-mac.sh`, which always fetches the latest release.
