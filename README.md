# ScreenFlow

A lightweight macOS menu-bar app that watches your screenshot folder, auto-copies new screenshots to your clipboard, and shows them in a large-thumbnail gallery.

## Download

Go to [Releases](../../releases/latest) and download `ScreenFlow.zip`. Unzip and move `ScreenFlow.app` to your Applications folder.

> **Note:** macOS will warn "unidentified developer" on first open. Right-click the app → Open → Open to bypass it.

## What it does

- Detects new screenshots within ~300ms (far faster than Finder's refresh)
- Auto-copies the screenshot to your clipboard — just press `⌘V` to paste
- Menu bar icon flashes ✓ when a screenshot is ready
- Click the icon to see your last 8 screenshots as thumbnails
- "Gallery →" opens a full window with adjustable large thumbnails, newest first
- "Launch at Login" checkbox in the menu

## BetterTouchTool integration (zero-delay workflow)

The native `⌘⇧4` shortcut shows a floating preview thumbnail for ~5 seconds before saving the file. To skip that entirely, install the CLI companion and bind a BTT shortcut to it:

**Install the CLI:**
```bash
sudo cp /path/to/screenflowctl /usr/local/bin/screenflowctl
```

**In BetterTouchTool**, create a trigger → Run Shell Script:
```
/usr/local/bin/screenflowctl capture
```

This gives you the same crosshair/selection experience but the file is saved immediately and auto-copied to clipboard. No waiting.

**Other CLI commands:**
```
screenflowctl capture       Take a screenshot (no thumbnail), auto-copy to clipboard
screenflowctl copy-latest   Copy the most recent screenshot to clipboard
screenflowctl open-gallery  Open the gallery window
screenflowctl list          Show recent screenshots
```

## Build from source

Requires macOS 13+ and Xcode Command Line Tools.

```bash
git clone https://github.com/YOUR_USERNAME/screenflow
cd screenflow
make open          # build + install to ~/Applications + launch
make install-ctl   # install screenflowctl to /usr/local/bin
make test          # run tests (requires Xcode.app)
make typecheck     # verify code compiles (CLT only, no Xcode needed)
```

## Releasing a new version

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will build the app and attach `ScreenFlow.zip` to the release automatically.
