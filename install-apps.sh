#!/bin/sh
# Build and install the NextBSD desktop apps and theme under your home folder,
# then set up ~/.zprofile, ~/.xinitrc and the desktop defaults.
# Run as a normal user, after build-core-libs.sh from nextbsd-gnustep.
#
# Usage: install-apps.sh [--with-windowmanager]

set -e

WINDOWMANAGER=no
case "${1:-}" in
    "") ;;
    --with-windowmanager) WINDOWMANAGER=yes ;;
    *)
        echo "usage: $0 [--with-windowmanager]" >&2
        exit 1
        ;;
esac

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

for repo in nextbsd-theme apps-terminal apps-fileviewer apps-dock apps-innerspace; do
    clone_or_pull "https://github.com/pkgdemon/$repo.git"
done

for repo in nextbsd-theme apps-terminal apps-fileviewer apps-dock apps-innerspace; do
    echo "==> Building $repo"
    cd "$SOURCES/$repo"
    gmake install
done

if [ "$WINDOWMANAGER" = yes ]; then
    clone_or_pull https://github.com/pkgdemon/gnustep-windowmanager.git
    echo "==> Building gnustep-windowmanager"
    cd "$SOURCES/gnustep-windowmanager"
    gmake
    gmake install
fi

echo "==> Setting desktop defaults"
defaults write NSGlobalDomain GSTheme NextBSD
defaults write NSGlobalDomain GSBackHandlesWindowDecorations NO
defaults write DockWM DockUseCellTileBackground YES
# 2 is DockPlacementRightTop.
defaults write DockWM DockPlacement 2

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

openapp DockWM.app &
DOCK_PID=$!
sleep 1

openapp FileViewer.app

kill $DOCK_PID
EOF
fi

echo "==> Done. Log in again, then run startx."
