#!/bin/zsh
set -euo pipefail

# Orifold DMG packager.
#
# Turns a built Orifold.app (or the release Orifold.zip that already contains it)
# into a drag-to-Applications disk image, emits a SHA-256 sidecar, and — when a
# Developer ID identity is present — code-signs, notarizes, and staples the image.
#
# Design notes (see docs/MACOS_DOWNLOAD_EXPERIENCE_PLAN.md §6):
#   * Uses `hdiutil create -srcfolder` (one shot, no attach/detach) so the CI
#     path is deterministic and free of the "Resource busy" flakiness that the
#     attach/AppleScript-layout/detach dance is known for. The image shows
#     Orifold.app beside an /Applications symlink — the essential install
#     affordance. A committed .DS_Store + branded background is a documented
#     follow-up; dropping scripts/assets/dmg-background.png in enables it.
#   * hdiutil is still wrapped in a 3-attempt retry — runner image bugs are real.
#   * Ad-hoc identity ("-") ⇒ dmg signing/notarization are skipped gracefully,
#     exactly like scripts/install-mac.sh does for the app.

PATH="/usr/bin:/bin:/usr/sbin:/sbin"

APP_NAME="Orifold"

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

APP_PATH=""
FROM_ZIP=""
OUTPUT=""
VERSION="${ORIFOLD_MARKETING_VERSION:-}"
SIGNING_IDENTITY="${ORIFOLD_SIGNING_IDENTITY:--}"
NOTARIZE="${ORIFOLD_NOTARIZE:-0}"
NOTARY_KEYCHAIN_PROFILE="${ORIFOLD_NOTARY_KEYCHAIN_PROFILE:-}"
APPLE_ID="${ORIFOLD_APPLE_ID:-}"
APPLE_TEAM_ID="${ORIFOLD_APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${ORIFOLD_APPLE_APP_SPECIFIC_PASSWORD:-}"

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/orifold-dmg.XXXXXX")"

usage() {
    cat <<USAGE
Orifold DMG packager

Usage:
  scripts/make-dmg.sh [--app PATH | --from-zip PATH] [--output PATH] [--version X.Y.Z]

Options:
  --app PATH        Package an existing Orifold.app bundle.
  --from-zip PATH   Package the Orifold.app inside a release zip.
  --output PATH     Write the .dmg here (default: Orifold-<version>-macOS-universal.dmg).
  --version X.Y.Z   Marketing version for the filename/volume (default: read from the app).
  --help            Show this help.

Signing/notarization reuse the same ORIFOLD_* env vars as scripts/install-mac.sh.
USAGE
}

fail() {
    printf "\nmake-dmg failed: %s\n" "$1" >&2
    exit 1
}

cleanup() {
    [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]] && /bin/rm -rf "$WORK_DIR"
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) shift; [[ $# -gt 0 ]] || fail "--app requires a path."; APP_PATH="$1" ;;
        --from-zip) shift; [[ $# -gt 0 ]] || fail "--from-zip requires a path."; FROM_ZIP="$1" ;;
        --output) shift; [[ $# -gt 0 ]] || fail "--output requires a path."; OUTPUT="$1" ;;
        --version) shift; [[ $# -gt 0 ]] || fail "--version requires a value."; VERSION="$1" ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

[[ "$(uname -s)" == "Darwin" ]] || fail "$APP_NAME disk images can only be built on macOS."
command -v hdiutil >/dev/null 2>&1 || fail "hdiutil was not found."

# ── Resolve the app bundle ──────────────────────────────────────────────────
if [[ -n "$FROM_ZIP" && -n "$APP_PATH" ]]; then
    fail "Pass either --app or --from-zip, not both."
fi

if [[ -n "$FROM_ZIP" ]]; then
    [[ -f "$FROM_ZIP" ]] || fail "Zip not found: $FROM_ZIP"
    printf "==> Expanding %s\n" "$FROM_ZIP"
    /usr/bin/ditto -x -k "$FROM_ZIP" "$WORK_DIR/unzip" || fail "Could not expand the zip."
    APP_PATH="$(/usr/bin/find "$WORK_DIR/unzip" -maxdepth 3 -name "$APP_NAME.app" -type d -print -quit)"
    [[ -n "$APP_PATH" ]] || fail "The zip did not contain $APP_NAME.app."
fi

[[ -n "$APP_PATH" ]] || fail "Provide --app or --from-zip."
[[ -d "$APP_PATH" ]] || fail "App bundle not found: $APP_PATH"

# ── Resolve version and output name ─────────────────────────────────────────
if [[ -z "$VERSION" ]]; then
    VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
fi
[[ -n "$VERSION" ]] || fail "Could not determine a version (pass --version or ensure the app has CFBundleShortVersionString)."

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$PWD/$APP_NAME-$VERSION-macOS-universal.dmg"
fi
# Normalize to an absolute path so the retry loop is cwd-independent.
OUTPUT_DIR="$(cd -- "$(dirname -- "$OUTPUT")" && pwd)"
OUTPUT="$OUTPUT_DIR/$(basename -- "$OUTPUT")"

VOLUME_NAME="$APP_NAME $VERSION"

# ── Stage the image contents ────────────────────────────────────────────────
STAGE="$WORK_DIR/stage"
/bin/mkdir -p "$STAGE"
printf "==> Staging %s\n" "$APP_NAME.app"
/usr/bin/ditto "$APP_PATH" "$STAGE/$APP_NAME.app" || fail "Could not stage the app."
/bin/ln -s /Applications "$STAGE/Applications" || fail "Could not create the /Applications symlink."

# Optional branded background (drop scripts/assets/dmg-background.png to enable).
background="$PROJECT_ROOT/scripts/assets/dmg-background.png"
if [[ -f "$background" ]]; then
    /bin/mkdir -p "$STAGE/.background"
    /bin/cp "$background" "$STAGE/.background/background.png"
fi

# Optional pre-baked Finder layout (committed .DS_Store makes the window pretty).
ds_store="$PROJECT_ROOT/scripts/assets/dmg-layout.DS_Store"
if [[ -f "$ds_store" ]]; then
    /bin/cp "$ds_store" "$STAGE/.DS_Store"
fi

# ── Create the compressed image, with retry ─────────────────────────────────
create_dmg_once() {
    /bin/rm -f "$OUTPUT"
    hdiutil create \
        -volname "$VOLUME_NAME" \
        -srcfolder "$STAGE" \
        -fs HFS+ \
        -format UDZO \
        -imagekey zlib-level=9 \
        -ov \
        "$OUTPUT"
}

printf "==> Building %s\n" "$(basename -- "$OUTPUT")"
created=0
for attempt in 1 2 3; do
    if create_dmg_once; then
        created=1
        break
    fi
    printf "    hdiutil attempt %s failed; retrying...\n" "$attempt" >&2
    /bin/sleep 5
done
[[ $created -eq 1 ]] || fail "hdiutil could not create the disk image after 3 attempts."

# ── Sign + notarize + staple the image (Developer ID only) ──────────────────
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
    printf "==> Signing disk image\n"
    codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$OUTPUT" \
        || fail "Could not sign the disk image."

    if [[ "$NOTARIZE" == "1" ]]; then
        command -v xcrun >/dev/null 2>&1 || fail "xcrun was not found, so notarization cannot run."
        printf "==> Submitting disk image for notarization\n"
        if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
            xcrun notarytool submit "$OUTPUT" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait \
                || fail "Disk image notarization failed."
        else
            [[ -n "$APPLE_ID" && -n "$APPLE_TEAM_ID" && -n "$APPLE_APP_SPECIFIC_PASSWORD" ]] \
                || fail "Notarization requires ORIFOLD_NOTARY_KEYCHAIN_PROFILE or ORIFOLD_APPLE_ID, ORIFOLD_APPLE_TEAM_ID, and ORIFOLD_APPLE_APP_SPECIFIC_PASSWORD."
            xcrun notarytool submit "$OUTPUT" \
                --apple-id "$APPLE_ID" \
                --team-id "$APPLE_TEAM_ID" \
                --password "$APPLE_APP_SPECIFIC_PASSWORD" \
                --wait || fail "Disk image notarization failed."
        fi
        printf "==> Stapling notarization ticket\n"
        xcrun stapler staple "$OUTPUT" || fail "Could not staple the notarization ticket to the disk image."
        xcrun stapler validate "$OUTPUT" || fail "Could not validate the stapled disk image."
    fi
else
    printf "==> Ad-hoc build: skipping disk-image signing and notarization.\n"
fi

# ── SHA-256 sidecar (shasum -c-compatible, filename-relative) ───────────────
printf "==> Writing checksum\n"
( cd "$OUTPUT_DIR" && shasum -a 256 "$(basename -- "$OUTPUT")" > "$(basename -- "$OUTPUT").sha256" )

printf "\n%s is ready.\n" "$APP_NAME disk image"
printf "DMG:      %s\n" "$OUTPUT"
printf "Checksum: %s.sha256\n" "$OUTPUT"
printf "Volume:   %s\n" "$VOLUME_NAME"
