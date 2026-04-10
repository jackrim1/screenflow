import Foundation
import AppKit
import ScreenFlowCore

// NSApplication.shared must be initialized before NSPasteboard works in a CLI.
_ = NSApplication.shared

func usage() {
    print("""
    screenflowctl — ScreenFlow command-line companion

    Usage:
      screenflowctl capture         Take a screenshot (no thumbnail delay) + copy to clipboard
      screenflowctl copy-latest     Copy the most recent screenshot to clipboard
      screenflowctl open-gallery    Tell the running ScreenFlow app to open its gallery
      screenflowctl list [N]        List the N most recent screenshots (default 10)
      screenflowctl path            Print the screenshot directory path
      screenflowctl help            Show this message

    BetterTouchTool integration
    ───────────────────────────
    Bind a shortcut to "Run Shell Script / Task":
      /usr/local/bin/screenflowctl capture      ← replaces ⌘⇧4 for zero-delay workflow
      /usr/local/bin/screenflowctl copy-latest  ← re-copy the most recent screenshot

    The `capture` command uses screencapture -i directly, which bypasses the
    floating thumbnail and writes the file immediately — no waiting.
    """)
}

/// Run screencapture interactively, save to destURL, copy to clipboard.
/// Returns false if the user cancelled (Escape key).
func runCapture(to destURL: URL) -> Bool {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    // -i  interactive selection (crosshair, same feel as ⌘⇧4)
    // no -P flag means no floating thumbnail preview
    proc.arguments = ["-i", destURL.path]
    do {
        try proc.run()
    } catch {
        fputs("Failed to launch screencapture: \(error)\n", stderr)
        return false
    }
    proc.waitUntilExit()
    // If user hit Escape, screencapture exits 0 but writes no file
    return FileManager.default.fileExists(atPath: destURL.path)
}

let args = CommandLine.arguments.dropFirst()
let command = args.first ?? "help"

switch command {

case "capture":
    let destDir = ScreenshotStore.defaultScreenshotDirectory()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    let filename = "Screenshot \(formatter.string(from: Date())).png"
    let destURL = destDir.appendingPathComponent(filename)

    guard runCapture(to: destURL) else {
        // User cancelled — exit silently
        exit(0)
    }

    guard ClipboardManager.copy(imageAt: destURL) else {
        fputs("Captured but failed to copy to clipboard\n", stderr)
        exit(1)
    }

    // Tell the running app to prepend this file to its gallery
    DistributedNotificationCenter.default().post(
        name: .init("com.screenflow.copyLatest"),
        object: nil
    )

    print("✓ Captured and copied: \(filename)")

case "copy-latest":
    // Signal the running app (so its UI updates too)
    DistributedNotificationCenter.default().post(
        name: .init("com.screenflow.copyLatest"),
        object: nil
    )
    // Also copy directly — this works even if the app is not running.
    let store = ScreenshotStore()
    // Give the store a tick to finish its synchronous directory scan
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))

    guard let latest = store.screenshots.first else {
        fputs("No screenshots found in \(store.directory.path)\n", stderr)
        exit(1)
    }
    guard ClipboardManager.copy(screenshot: latest) else {
        fputs("Failed to copy \(latest.filename) to clipboard\n", stderr)
        exit(1)
    }
    print("✓ Copied \(latest.filename)")

case "open-gallery":
    DistributedNotificationCenter.default().post(
        name: .init("com.screenflow.openGallery"),
        object: nil
    )
    // Give the notification a moment to be delivered
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
    print("✓ Sent open-gallery signal to ScreenFlow")

case "list":
    let limit = args.dropFirst().first.flatMap(Int.init) ?? 10
    let store = ScreenshotStore()
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    if store.screenshots.isEmpty {
        print("No screenshots found in \(store.directory.path)")
    } else {
        for shot in store.screenshots.prefix(limit) {
            print("\(formatter.string(from: shot.createdAt))  \(shot.filename)")
        }
    }

case "path":
    print(ScreenshotStore.defaultScreenshotDirectory().path)

case "help", "--help", "-h":
    usage()

default:
    fputs("Unknown command: \(command)\n", stderr)
    usage()
    exit(1)
}
