#!/bin/zsh
set -euo pipefail

APP_NAME="PDFold"
REPO="udhawan97/PDFold"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"
WORK_DIR="$HOME/.pdfold"
SRC_DIR="$WORK_DIR/src"
INSTALLER="$SRC_DIR/scripts/install-mac.sh"

print_step() {
    printf "\n==> %s\n" "$1"
}

print_note() {
    printf "    %s\n" "$1"
}

fail() {
    printf "\nInstall failed: %s\n" "$1" >&2
    exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "$APP_NAME only runs on macOS."

mkdir -p "$WORK_DIR"

print_step "Installing or updating $APP_NAME"
print_note "Trying the prebuilt app first. No Xcode or Command Line Tools needed."

REMOTE_INSTALLER="$WORK_DIR/install-mac.sh"
if /usr/bin/curl -fsSL "$RAW_BASE/scripts/install-mac.sh" -o "$REMOTE_INSTALLER"; then
    chmod +x "$REMOTE_INSTALLER" 2>/dev/null || true
    if /bin/zsh "$REMOTE_INSTALLER" --prebuilt-only; then
        exit 0
    fi
    print_note "A prebuilt release was not available. Falling back to a local source build."
else
    print_note "Could not download the remote installer. Falling back to a local source build."
fi

if ! command -v swift >/dev/null 2>&1; then
    print_step "Apple Command Line Tools are needed for the fallback build"
    print_note "macOS will show Apple's installer. When it finishes, paste the one-line command again."
    xcode-select --install >/dev/null 2>&1 || true
    exit 1
fi

print_step "Downloading source"
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"

if command -v git >/dev/null 2>&1; then
    git clone --depth 1 "https://github.com/$REPO.git" "$SRC_DIR"
else
    TARBALL="$WORK_DIR/source.tar.gz"
    /usr/bin/curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" -o "$TARBALL"
    /usr/bin/tar -xzf "$TARBALL" -C "$WORK_DIR"
    mv "$WORK_DIR/PDFold-main" "$SRC_DIR"
fi

[[ -f "$INSTALLER" ]] || fail "Source downloaded, but the installer was not found."
chmod +x "$INSTALLER" 2>/dev/null || true
exec /bin/zsh "$INSTALLER"
