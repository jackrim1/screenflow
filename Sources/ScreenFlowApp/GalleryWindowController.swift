import AppKit
import SwiftUI
import ScreenFlowCore

class GalleryWindowController: NSWindowController {
    convenience init(store: ScreenshotStore) {
        let hosting = NSHostingController(rootView: GalleryView(store: store))
        let window = NSWindow(contentViewController: hosting)
        window.title = "ScreenFlow"
        window.setContentSize(NSSize(width: 920, height: 620))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 520, height: 400)
        window.center()
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
