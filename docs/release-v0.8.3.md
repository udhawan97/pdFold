# v0.8.3 Orifold

## GitHub Release Fields

Tag: `release-v0.8.3`

Target: latest commit tagged by `release-v0.8.3`

Release title: `v0.8.3 Orifold`

Assets to upload (all produced automatically by `release.yml`):

- `Orifold-0.8.3-macOS-universal.dmg` — the drag-to-Applications disk image (primary download)
- `Orifold-0.8.3-macOS-universal.dmg.sha256` — checksum sidecar
- `Orifold.dmg` — byte-identical stable-name alias, so `releases/latest/download/Orifold.dmg` never breaks
- `Orifold.dmg.sha256`
- `manifest.json` — version, build, date, size, checksum, min macOS, architecture
- `Orifold.zip` — unchanged; still drives the one-line installer, Homebrew cask, and `.command` helpers

Automation: `.github/workflows/release.yml` builds a **universal (Apple Silicon + Intel)** app on push of any `release-v*` tag, packages the DMG via `scripts/make-dmg.sh`, publishes the tagged release as GitHub's "latest" (`make_latest: true`), and dispatches a docs-site rebuild so the download page reflects the new version.

Build the assets locally with:

```zsh
ORIFOLD_UNIVERSAL=1 ./scripts/install-mac.sh --package-only --package /tmp/Orifold.zip
zsh scripts/make-dmg.sh --from-zip /tmp/Orifold.zip --version 0.8.3
```

## Release Notes

# v0.8.3 Orifold

**Release:** Latest release
**Tag:** [`release-v0.8.3`](https://github.com/udhawan97/Orifold/releases/tag/release-v0.8.3)

---

## What Changed Since v0.8.2

v0.8.3 is a distribution release: Orifold now ships as a **universal binary** that runs natively on both Apple Silicon and Intel Macs, delivered through a proper **drag-to-Applications DMG** with published checksums and a machine-readable release manifest. The website gets a polished, honest "Download for macOS" experience to match. No document-editing behavior changes in this release.

### Universal builds (Apple Silicon + Intel)

- The release app is now a universal 2 binary (`arm64` + `x86_64`), so it runs natively on Apple Silicon and on Intel Macs — one download works for both. The bundled PDFium and qpdf engines already shipped fat slices; the app executable now matches.
- The build path is a single `swift build --arch arm64 --arch x86_64` behind `ORIFOLD_UNIVERSAL=1`, with a `lipo` assertion that fails the build if the result isn't actually fat.

### A real DMG installer

- Downloads now arrive as `Orifold-0.8.3-macOS-universal.dmg` — open it, drag Orifold into Applications, launch from Applications. The disk image contains the app beside an `/Applications` symlink, the standard macOS install affordance.
- New `scripts/make-dmg.sh` builds the image deterministically (`hdiutil`, retry-wrapped for the known runner "Resource busy" flakiness), emits a SHA-256 sidecar, and code-signs / notarizes / staples the image when Developer ID credentials are present.
- A stable-name `Orifold.dmg` alias is published alongside the versioned file, so `releases/latest/download/Orifold.dmg` is a permanent, never-changing link.
- Every release now carries a `manifest.json` (version, build, date, file size, checksum, minimum macOS, architecture) for scripting and future update tooling.

### Website download experience

- The landing page's hero and download band now lead with a polished **"Download for macOS"** button — icon, "Apple Silicon + Intel" sub-label, and a file-details line (`macOS 14+ · Universal DMG · v0.8.3 · <size>`) — plus a "View install instructions" link.
- A clean three-step **"Install Orifold on macOS"** section (open the DMG → drag to Applications → open from Applications) with honest, per-macOS-version first-launch coaching.
- A "Starting download…" feedback state and a "Download didn't start?" recovery line, a "Need another version?" block (Universal DMG, direct zip, Homebrew, release notes, checksum-verify command), and a "Having trouble installing?" support link.
- All version, size, and download-URL values are baked from GitHub release metadata at build time (correct with JavaScript disabled) and confirm-or-upgrade refreshed in the browser — never hardcoded.

### Trademark / trust notes

- The download button uses a neutral, custom download glyph — **not** the Apple logo or an SF Symbol, both of which are license-restricted for web use. The "Signed and notarized for macOS" trust line is gated behind a `signedBuilds` flag and stays off until a Developer ID notarized build actually ships; today's builds remain ad-hoc signed and honestly labeled.

---

## Known Limitations

- **Not notarized yet.** Release builds are ad-hoc signed, so first launch still takes one guided step (the one-line installer and Homebrew cask clear quarantine automatically; the DMG path is coached per macOS version on the site and in the docs). Apple notarization is the next distribution milestone and requires an Apple Developer Program membership.
- **Intel is built but lightly exercised.** The universal binary is produced and asserted fat in CI; broad Intel-hardware QA is ongoing. Report anything Intel-specific in Issues.
- The DMG ships the functional app + `/Applications` window; a fully branded background and pre-baked Finder layout are a tracked polish follow-up (drop `scripts/assets/dmg-background.png` + `dmg-layout.DS_Store` to enable — `make-dmg.sh` already looks for them).
- Automated end-to-end UI smoke testing, rotated-page decoration/form/signature baking, stable annotation-undo handles, and byte-identical unedited exports remain open items from prior cycles.

---

## Upgrade Notes

Existing installs update automatically via the **Orifold.command** Desktop launcher, or Homebrew. New installs can now use the DMG:

1. Download `Orifold-0.8.3-macOS-universal.dmg`.
2. Open it and drag **Orifold** into **Applications**.
3. Open Orifold from Applications.

The one-line installer still works unchanged:

```zsh
curl -fsSL https://raw.githubusercontent.com/udhawan97/Orifold/main/install.sh | zsh
```

No data migration is required; no settings or documents are affected by this release.

---

Orifold folds a thousand messy pages so you never have to. The crane stays; the chaos doesn't.
