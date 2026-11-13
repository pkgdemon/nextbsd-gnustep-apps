#!/bin/sh
# Build and install the NextBSD desktop apps and theme under your home folder,
# then set up ~/.zprofile, ~/.xinitrc and the desktop defaults.
# Run as a normal user, after build-core-libs-nextbsd-dispatch.sh and
# build-windowserver.sh from nextbsd-gnustep.
#
# XLibre.app runs X11 programs on WindowServer, as XQuartz does on macOS:
# open it and it starts an xterm with NextBSD title bars, and X programs run
# rootless beside the GNUstep apps. Its X server, Xnextbsd, can't be built
# on NextBSD yet (no meson or ninja), so the binary for this machine is
# fetched from apps-xlibre's CI release and checked against its SHA-256.
# If that fails, XLibre.app is installed without it.

set -e

if [ "$(id -u)" -eq 0 ]; then
    echo "$0: run this as a normal user, not root" >&2
    exit 1
fi

# GNUstep.sh isn't written to run under set -e.
set +e
. /System/Library/Makefiles/GNUstep.sh
set -e
export LIBRARY_PATH=/usr/X11/lib:/Developer/Link
export CPATH=/usr/X11/include
export GNUSTEP_INSTALLATION_DOMAIN=USER

SOURCES=$HOME/Library/Sources
mkdir -p "$SOURCES"

clone_or_pull() {
    dir=$SOURCES/$(basename "$1" .git)
    if [ -d "$dir/.git" ]; then
        git -C "$dir" pull --ff-only
    else
        git clone "$1" "$dir"
    fi
}

for repo in nextbsd-theme apps-terminal apps-workspace apps-dock apps-innerspace apps-xlibre apps-settings; do
    clone_or_pull "https://github.com/nextbsd/$repo.git"
done

XNEXTBSD_URL=https://github.com/nextbsd/apps-xlibre/releases/download/xnextbsd-latest
XNEXTBSD_DIR=$(mktemp -d)
XNEXTBSD=

# Sets XNEXTBSD to the downloaded binary if it arrives and its SHA-256 matches.
fetch_xnextbsd() {
    file=$XNEXTBSD_DIR/Xnextbsd-$(uname -m)
    fetch -q -o "$file" "$XNEXTBSD_URL/${file##*/}" || return 1
    fetch -q -o "$file.sha256" "$XNEXTBSD_URL/${file##*/}.sha256" || return 1
    want=$(awk '{ print $1; exit }' "$file.sha256")
    have=$(sha256 -q "$file")
    if [ -z "$want" ] || [ "$want" != "$have" ]; then
        echo "$0: ${file##*/}: SHA-256 is $have, expected $want" >&2
        return 1
    fi
    chmod 755 "$file"
    XNEXTBSD=$file
}

echo "==> Fetching Xnextbsd for $(uname -m)"
if ! fetch_xnextbsd; then
    echo "warning: couldn't fetch Xnextbsd, so XLibre.app is installed without its X server." >&2
    echo "Re-run this script later to add it." >&2
fi

for repo in nextbsd-theme apps-terminal apps-workspace apps-dock apps-innerspace apps-xlibre apps-settings; do
    echo "==> Building $repo"
    cd "$SOURCES/$repo"
    if [ "$repo" = apps-xlibre ] && [ -n "$XNEXTBSD" ]; then
        gmake install XNEXTBSD="$XNEXTBSD"
    else
        gmake install
    fi
done
rm -rf "$XNEXTBSD_DIR"

# FileViewer was renamed Workspace; don't leave the old app beside it.
if [ -d "$HOME/Applications/FileViewer.app" ]; then
    echo "==> Removing the old FileViewer.app (now Workspace.app)"
    rm -rf "$HOME/Applications/FileViewer.app"
fi

# WindowManager became XLibre.app; don't leave the old app beside it.
if [ -d "$HOME/Applications/WindowManager.app" ]; then
    echo "==> Removing the old WindowManager.app (now XLibre.app)"
    rm -rf "$HOME/Applications/WindowManager.app"
fi

echo "==> Setting desktop defaults"
defaults write NSGlobalDomain GSTheme NextBSD
defaults write NSGlobalDomain GSBackHandlesWindowDecorations NO
defaults write DockWM DockUseCellTileBackground YES
# 2 is DockPlacementRightTop.
defaults write DockWM DockPlacement 2
# Apps show no app icon of their own; the Dock shows them, as on NeXTSTEP.
defaults write NSGlobalDomain GSSuppressAppIcon YES

# Only the marked block is replaced, so the rest of the file is left alone.
echo "==> Updating ~/.zprofile"
BLOCK_BEGIN="# BEGIN nextbsd-gnustep-apps"
BLOCK_END="# END nextbsd-gnustep-apps"
ZPROFILE_TMP=$(mktemp)
if [ -f "$HOME/.zprofile" ]; then
    sed "/^$BLOCK_BEGIN\$/,/^$BLOCK_END\$/d" "$HOME/.zprofile" > "$ZPROFILE_TMP"
fi
cat >> "$ZPROFILE_TMP" <<EOF
$BLOCK_BEGIN
source /System/Library/Makefiles/GNUstep.sh
export LIBRARY_PATH=/usr/X11/lib:/Developer/Link
export CPATH=/usr/X11/include
export GNUSTEP_INSTALLATION_DOMAIN="USER"
$BLOCK_END
EOF
cat "$ZPROFILE_TMP" > "$HOME/.zprofile"
rm -f "$ZPROFILE_TMP"

case "${SHELL:-}" in
    */zsh) ;;
    *) echo "warning: only zsh reads ~/.zprofile, and your shell is ${SHELL:-unknown}" >&2 ;;
esac

# An existing .xinitrc may be a custom session, so it is never changed.
if [ -e "$HOME/.xinitrc" ]; then
    echo "==> Leaving your ~/.xinitrc as it is. See the README for what it should contain."
else
    echo "==> Creating ~/.xinitrc"
    cat > "$HOME/.xinitrc" <<'EOF'
. /System/Library/Makefiles/GNUstep.sh

# A gpbs left over from an earlier X session is still registered but
# attached to a dead display, so every app waits 30 s on it before
# starting a new one. Start a fresh one for this display instead.
pkill -u "$USER" -x gpbs
/System/Library/Tools/gpbs --daemon &
sleep 1

openapp DockWM.app &
DOCK_PID=$!
sleep 1

openapp Workspace.app

kill $DOCK_PID
# gpbs is tied to this display, so don't leave it for the next session.
pkill -u "$USER" -x gpbs
EOF
fi

echo "==> Done. Log out, then log in again at the login window"
echo "(nextbsd-gnustep's enable-loginwindow.sh turns it on). For an X11"
echo "session instead, log in again on the text console and run startx."
