# nextbsd-gnustep-apps

Builds a desktop of GNUstep apps on NextBSD, as a normal user, and sets up the session to run it.

Install the packages and core libraries from [nextbsd-gnustep](https://github.com/pkgdemon/nextbsd-gnustep) first.

## Install

Run this as your normal user:

```sh
git clone https://github.com/pkgdemon/nextbsd-gnustep-apps.git /private/tmp/nextbsd-gnustep-apps
cd /private/tmp/nextbsd-gnustep-apps
./install-apps.sh
```

Log in again afterwards, then start the desktop with `startx`.

The script can be re-run. Existing clones are updated with `git pull --ff-only`, and it stops at the first failure.

### Apps

| Repository | What it provides |
|---|---|
| [nextbsd-theme](https://github.com/pkgdemon/nextbsd-theme) | The NextBSD dark theme, its icons and fonts |
| [apps-terminal](https://github.com/pkgdemon/apps-terminal) | Terminal, with colors the theme can set |
| [apps-fileviewer](https://github.com/pkgdemon/apps-fileviewer) | FileViewer |
| [apps-dock](https://github.com/pkgdemon/apps-dock) | The Dock (`DockWM.app`) |
| [apps-innerspace](https://github.com/pkgdemon/apps-innerspace) | InnerSpace, a live desktop background |
| [gnustep-windowmanager](https://github.com/pkgdemon/gnustep-windowmanager) | Optional title bars for plain X11 programs |

Repositories are cloned into `~/Library/Sources`. Apps install to `~/Applications`, the theme to `~/Library/Themes`, and its fonts to `~/Library/Fonts`.

WindowManager is only built with `./install-apps.sh --with-windowmanager`. You only need it for programs that aren't GNUstep apps, such as `xterm`.

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

The script creates this file only if you don't have one. An existing `.xinitrc` is left alone, so add these lines yourself if you want this session.

```sh
. /System/Library/Makefiles/GNUstep.sh

openapp DockWM.app &
DOCK_PID=$!
sleep 1

openapp FileViewer.app

kill $DOCK_PID
```

FileViewer runs in the foreground, so quitting it ends the session.

### Defaults

```sh
defaults write NSGlobalDomain GSTheme NextBSD
defaults write NSGlobalDomain GSBackHandlesWindowDecorations NO
defaults write DockWM DockUseCellTileBackground YES
defaults write DockWM DockPlacement 2
```

| Default | Why |
|---|---|
| `GSTheme NextBSD` | Turns on the NextBSD dark theme |
| `GSBackHandlesWindowDecorations NO` | Makes GNUstep draw its own title bars. This session has no window manager, so with `YES` nothing would draw them. The optional WindowManager doesn't change this, because it leaves GNUstep windows alone. |
| `DockUseCellTileBackground YES` | Makes the Dock use the theme's dark tile. This is the **Use common_Tile** option in the Dock's settings. |
| `DockPlacement 2` | Puts the Dock at the top of the right side of the screen. This is the **Right Top** placement in the Dock's settings. |

## Using the desktop

To go back to the default look, run `defaults write NSGlobalDomain GSTheme GNUstep` and reopen your apps.

Open `InnerSpace.app` from FileViewer or the Dock. It runs as a live background behind your other windows, and its **Run** menu item starts the full-screen saver. It loads modules from `~/Library/InnerSpace`, not `~/Library/Bundles`.

Start WindowManager when you need it with `openapp WindowManager.app`, and leave it out of `.xinitrc`. Stop it with `pkill -x WindowManager`.

## Known limitations

- FileViewer copies and recursively deletes folders through `/proc/self/fd/...`, and NextBSD has no `/proc`. Expect those two operations to fail.
- Translucency needs a compositor that honors window opacity, so it isn't available in this setup.
- Theme icons are normal resolution, and may look soft at 2× display scaling.

## Guide

This script automates a wiki guide, which explains the steps in more detail:

- [Building GNUstep apps on NextBSD](https://github.com/pkgdemon/pkgdemon.github.io/wiki/Building-GNUstep-Apps-on-NextBSD)
