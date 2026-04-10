import AppKit

public enum ClipboardManager {
    public static func copy(screenshot: Screenshot) -> Bool {
        copy(imageAt: screenshot.url)
    }

    public static func copy(imageAt url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.writeObjects([image])
    }

    public static func hasImage() -> Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    public static func currentChangeCount() -> Int {
        NSPasteboard.general.changeCount
    }
}
