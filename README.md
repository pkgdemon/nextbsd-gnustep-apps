# nextbsd-gnustep-apps

Builds a desktop of GNUstep apps on NextBSD, as a normal user, and sets up the session to run it.

Install the packages, core libraries and WindowServer from [nextbsd-gnustep](https://github.com/pkgdemon/nextbsd-gnustep) first. Its [Install the NextBSD desktop](https://github.com/pkgdemon/nextbsd-gnustep#install-the-nextbsd-desktop) section lists every step, this script included.

## Install

Run this as your normal user:

```sh
git clone https://github.com/pkgdemon/nextbsd-gnustep-apps.git /private/tmp/nextbsd-gnustep-apps
cd /private/tmp/nextbsd-gnustep-apps
./install-apps.sh
```

Afterwards, log out and log in again at the login window (nextbsd-gnustep's `enable-loginwindow.sh` turns it on). Your session starts InnerSpace, the Dock and Workspace. For an X11 session instead, log in again on the text console and run `startx` (see [`~/.xinitrc`](#xinitrc)).

The script can be re-run. Existing clones are updated with `git pull --ff-only`, and it stops at the first failure.

### Apps

| Repository | What it provides |
|---|---|
| [nextbsd-theme](https://github.com/nextbsd/nextbsd-theme) | The NextBSD dark theme, its icons and fonts |
| [apps-terminal](https://github.com/nextbsd/apps-terminal) | Terminal, with colors the theme can set |
| [apps-workspace](https://github.com/nextbsd/apps-workspace) | Workspace (`Workspace.app`, formerly FileViewer) and its File Viewer windows |
| [apps-dock](https://github.com/nextbsd/apps-dock) | The Dock (`DockWM.app`) |
| [apps-innerspace](https://github.com/nextbsd/apps-innerspace) | InnerSpace, a live desktop background |
| [apps-xlibre](https://github.com/nextbsd/apps-xlibre) | XLibre (`XLibre.app`), X11 programs on WindowServer, with `Xnextbsd`, its X server, inside it |
| [apps-settings](https://github.com/nextbsd/apps-settings) | The settings apps: Displays (`Displays.app`), the display's "looks like" size on HiDPI screens |

FileViewer was renamed Workspace. The script removes an old `~/Applications/FileViewer.app`, and Workspace copies FileViewer's settings the first time it starts.

WindowManager became XLibre. The script removes an old `~/Applications/WindowManager.app`.

The app repositories moved from pkgdemon to the nextbsd org, and two were renamed: apps-fileviewer is now apps-workspace, and gnustep-windowmanager is now apps-xlibre. The script clones those two fresh into `~/Library/Sources`; you can delete the old `apps-fileviewer` and `gnustep-windowmanager` folders there.

Repositories are cloned into `~/Library/Sources`. Apps install to `~/Applications`, the theme to `~/Library/Themes`, and its fonts to `~/Library/Fonts`.

### XLibre and its X server

XLibre runs X11 programs on WindowServer, as XQuartz does on macOS. Open it and it starts an `xterm`; X programs started from there run rootless, each X window in its own WindowServer window with a NextBSD title bar, beside your GNUstep apps. `xterm` and the X client libraries come from the `NextBSD-xlibre` and `NextBSD-xlibs` packages.

Its X server, `Xnextbsd`, is built with meson and ninja, which NextBSD doesn't have yet, so apps-xlibre's CI builds it for every commit and publishes it on the [`xnextbsd-latest`](https://github.com/nextbsd/apps-xlibre/releases/tag/xnextbsd-latest) release. The script fetches the one for your machine (`Xnextbsd-amd64` or `Xnextbsd-arm64`, by `uname -m`) with `fetch`, checks it against its `.sha256` file with `sha256`, and installs it inside the app as `XLibre.app/Resources/Xnextbsd`. If the download or the check fails, it warns and installs XLibre without its X server; re-run the script to add it.

## Session setup

`install-apps.sh` does all of this for you.

### `~/.zprofile`

The script adds these lines between `# BEGIN nextbsd-gnustep-apps` and `# END nextbsd-gnustep-apps` markers. Re-running it replaces only that block. Only zsh reads this file, so the script warns if your login shell is something else.

```sh
source /System/Library/Makefiles/GNUstep.sh
export LIBRARY_PATH=/usr/X11/lib:/Developer/Link
export CPATH=/usr/X11/include
export GNUSTEP_INSTALLATION_DOMAIN="USER"
```

### `~/.xinitrc`

The login window doesn't use this file. It's for an X11 session started with `startx` from the text console, with GNUstep's X11 backend and Xorg (the `NextBSD-xlibre` package). XLibre needs WindowServer, so it doesn't run in this session.

The script creates this file only if you don't have one. An existing `.xinitrc` is left alone, so add these lines yourself if you want this session.

```sh
. /System/Library/Makefiles/GNUstep.sh

pkill -u "$USER" -x gpbs
/System/Library/Tools/gpbs --daemon &
sleep 1

openapp DockWM.app &
DOCK_PID=$!
sleep 1

openapp Workspace.app

kill $DOCK_PID
pkill -u "$USER" -x gpbs
```

Workspace runs in the foreground, so quitting it ends the session.

The `gpbs` lines start a fresh pasteboard server for each session and stop it at the end. A `gpbs` left over from an earlier X session is still registered but attached to a display that's gone. Every app then waits 30 seconds on it before starting a new one, which shows as a black screen after `startx`. If you already have a `.xinitrc`, add these lines to it.

### Defaults

```sh
defaults write NSGlobalDomain GSTheme NextBSD
defaults write NSGlobalDomain GSBackHandlesWindowDecorations NO
defaults write DockWM DockUseCellTileBackground YES
defaults write DockWM DockPlacement 2
defaults write NSGlobalDomain GSSuppressAppIcon YES
```

| Default | Why |
|---|---|
| `GSTheme NextBSD` | Turns on the NextBSD dark theme |
| `GSBackHandlesWindowDecorations NO` | Makes GNUstep draw its own title bars. The X11 session has no window manager, so with `YES` nothing would draw them there. |
| `DockUseCellTileBackground YES` | Makes the Dock use the theme's dark tile. This is the **Use common_Tile** option in the Dock's settings. |
| `DockPlacement 2` | Puts the Dock at the top of the right side of the screen. This is the **Right Top** placement in the Dock's settings. |
| `GSSuppressAppIcon YES` | Apps show no app icon of their own; the Dock shows them, as on NeXTSTEP. Minimized windows still go to the bottom of the screen. |

## Using the desktop

To go back to the default look, run `defaults write NSGlobalDomain GSTheme GNUstep` and reopen your apps.

Open `InnerSpace.app` from Workspace or the Dock. It runs as a live background behind your other windows, and its **Run** menu item starts the full-screen saver. It loads modules from `~/Library/InnerSpace`, not `~/Library/Bundles`.

Open `XLibre.app` from Workspace or the Dock, or with `openapp XLibre.app`, to run X11 programs. Its menu starts another `xterm`, and it asks before quitting while X programs are running.

## Known limitations

- Translucency needs a compositor that honors window opacity, so it isn't available in this setup.
- Theme icons are normal resolution, and may look soft at 2× display scaling.

## Guide

This script automates a wiki guide, which explains the steps in more detail:

- [Building GNUstep apps on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep-Apps-on-NextBSD)
