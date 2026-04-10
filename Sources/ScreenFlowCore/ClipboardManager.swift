import AppKit

public enum ClipboardManager {
    public static func copy(screenshot: Screenshot) -> Bool {
        copy(imageAt: screenshot.url)
    }

    public static func copy(imageAt url: URL) -> Bool {
        guard let image = NSImage(contentsOf: url) else { return false }
        let pb = NSPasteboard.general
        pb.clearContents()
        // Write both the image data and the file URL so receiving apps can use
        // whichever they support. Apps that reject pasted image data (e.g. some
        // web UIs) will often accept a file URL and treat it like a drag-and-drop.
        return pb.writeObjects([image, url as NSURL])
    }

    public static func hasImage() -> Bool {
        NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    public static func currentChangeCount() -> Int {
        NSPasteboard.general.changeCount
    }
}
