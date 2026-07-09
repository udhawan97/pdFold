# v0.8.7 Orifold

## GitHub Release Fields

Tag: `v0.8.7`

Target: latest commit tagged by `v0.8.7`

Release title: `v0.8.7 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.7-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.7-macOS-universal.dmg.sha256` — checksum sidecar (also what the in-app updater verifies against)
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `v*` / `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, runs the packaged-app smoke gate, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.7
```

## Release Notes

# v0.8.7 Orifold

**Release:** Latest release
**Tag:** [`v0.8.7`](https://github.com/udhawan97/Orifold/releases/tag/v0.8.7)

---

## What Changed Since v0.8.6

v0.8.7 is an **under-the-hood release** — no editing, update-flow, or UI changes this cycle. It ships the first two build-outs of a professional object-editing system (select, move, resize, delete, and restyle shapes, lines, and images inside a PDF). The new code is dormant: it is not called from any menu, tool, or view yet, so nothing changes for users in this release.

### Added: the object-editing foundation (internal, not yet user-facing)

- **A permanent proof that the risky part works.** The design's biggest open question was whether Orifold's PDF engine could move and delete individual page objects (a line, a shape, an image) and reload the file with no leftover artifacts, no lost text, and a stable identity for each object across a save/reopen round trip. A dedicated test now proves this on real PDF bytes, not just in memory, and stays in the suite permanently as a regression guard.
- **A real bug found and fixed before it could ship.** While proving the above, the engine call that rewrites a page's contents was found to silently drop the color of redrawn shapes — a saved page could come back with the right geometry but the wrong colors. Fixed with a targeted correction plus a permanent regression test, well ahead of any feature that would have surfaced it to users.
- **The object model and detection engine.** A new read-only pass walks a page's lines, shapes, and images, classifies which ones can safely be edited later, and assigns each a stable identity that survives being saved and reopened — the foundation the actual select/move/resize/delete UI will build on in a future release.

### Fixed

- **A crash-safety gap in the new code.** A malformed or adversarial PDF could have fed an extreme or invalid coordinate into the object-identity calculation and crashed the app; it's now clamped to a safe range and covered by a regression test. Caught and fixed before this code is reachable from anywhere a user can trigger it.
- **An identity collision in the new code.** Two different images of the same pixel dimensions were computing the same internal identity, which would have caused an edit on one to misapply to the other once editing ships. Fixed by folding in a sampled content hash, with a regression test.
- **A CI gate that had gone red.** A naming-convention slip in a test file was failing the lint check and, as a side effect, skipping the whole test suite in CI. Fixed and verified with a full project-wide lint pass (zero errors) and a full green test run.

### Under the hood

- New files: `PDFObjectDetectionEngine.swift`, `PDFiumObjectBindings.swift`, `PDFObjectEditingModels.swift`, plus two new permanent test files. `Workspace` gained a new, empty-by-default `objectEditStates` field (schema version bumped 5→6); existing saved documents load unchanged.
- Verified via a 6-pass adversarial review (C-interop/memory-safety, model/schema, detection logic, concurrency, and two independent regression/integration passes) plus two independent manual re-checks of every fix before it shipped. Full test suite: 662 tests, all green. Full-project SwiftLint: zero errors.

## Install / Upgrade

1. Download `Orifold-0.8.7-macOS-universal.dmg` (or the stable-name `Orifold.dmg`).
2. Open it and drag **Orifold** into **Applications**.
3. Launch from Applications. Existing users on v0.8.6 will be offered v0.8.7 by the in-app updater, or can re-run `scripts/install-mac.sh`, which always fetches the latest release.
