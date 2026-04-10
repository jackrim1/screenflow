# ScreenFlow — Setup Guide

A lightweight macOS menu-bar app that watches your screenshot folder, auto-copies new screenshots to the clipboard, and shows them in a large-thumbnail gallery.

---

## Requirements

- macOS 13+
- **Xcode.app** (free from the App Store) — required for `swift build` and `swift test`

> If you only have Command Line Tools, run `make typecheck` to verify all source
> compiles, and `make fix-clt` (once, with sudo) to patch the platform symlink
> that lets SPM resolve packages. Full `make test` still needs Xcode.app because
> XCTest.framework is only shipped with Xcode.

---

## Build & Install

```bash
# 1. Build, bundle, and install to ~/Applications
make open

# 2. Install the CLI companion (used by BetterTouchTool)
make install-ctl

# 3. Run tests
make test

# 4. Verify code compiles (no Xcode needed)
make typecheck
```

The app runs as a **menu bar icon only** (no dock entry).

---

## Day-to-day workflow

| Action | How |
|---|---|
| Take a screenshot | `⌘⇧4` as usual |
| Paste it anywhere | `⌘V` — it's already in your clipboard |
| Browse all screenshots | Click the menu bar icon → **Gallery →** |
| Re-copy an older screenshot | Click it in the popover or gallery |
| Adjust thumbnail size | Drag the slider in the gallery toolbar |

---

## BetterTouchTool integration

After running `make install-ctl`, configure BTT triggers to run shell scripts:

| BTT action | Shell command |
|---|---|
| Copy latest screenshot | `/usr/local/bin/screenflowctl copy-latest` |
| Open gallery window | `/usr/local/bin/screenflowctl open-gallery` |

**Suggested BTT shortcut**: `⌘⇧V` → `copy-latest`
So the full flow is: `⌘⇧4` screenshot, then `⌘⇧V` to ensure it's in clipboard, then `⌘V` to paste.

(In practice you often won't need the BTT shortcut because the app auto-copies on detection.)

---

## CLI reference

```
screenflowctl copy-latest     Copy the most recent screenshot to clipboard
screenflowctl open-gallery    Tell the running app to open the gallery window
screenflowctl list [N]        List the N most recent screenshots (default 10)
screenflowctl path            Print the screenshot directory path
```

---

## How it works

1. On launch, `ScreenshotWatcher` registers an **FSEvents** stream on your screenshot folder.
2. When a new `.png`/`.jpg` file matching `Screenshot*`, `Screen Shot*`, or `CleanShot*` appears, the app waits 300ms (to let macOS finish writing), then copies it to the clipboard automatically.
3. The menu bar icon flashes a ✓ so you know it's ready to paste.
4. The gallery shows all screenshots sorted newest-first with adjustable thumbnail sizes.

---

## Screenshot folder

macOS stores your preference in `com.apple.screencapture` → `location`.  
ScreenFlow reads that automatically. Default is `~/Desktop`.

To check: `screenflowctl path`

---

## Running tests

```bash
make test         # quiet output
make test-verbose # show each test name
```

Tests cover:
- `Screenshot` model equality and hashing
- `ScreenshotStore` loading, sorting, deduplication
- `ScreenshotWatcher` FSEvents detection and stop behaviour  
- `ClipboardManager` copy/read operations
