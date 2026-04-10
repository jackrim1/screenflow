import AppKit
import ScreenFlowCore

// ObservableObject so @NSApplicationDelegateAdaptor can publish changes to SwiftUI
// (used to flash the menu bar icon when a screenshot is auto-copied).
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var menuBarIconName = "photo.stack"

    let store = ScreenshotStore()
    private var watcher: ScreenshotWatcher?
    private var galleryController: GalleryWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let watcher = ScreenshotWatcher(store: store)
        self.watcher = watcher

        watcher.onNewScreenshot = { [weak self] screenshot in
            if ClipboardManager.copy(screenshot: screenshot) {
                self?.flashIcon()
            }
        }

        watcher.start()

        // Listen for screenflowctl signals
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleCopyLatest),
            name: .init("com.screenflow.copyLatest"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleOpenGallery),
            name: .init("com.screenflow.openGallery"),
            object: nil
        )
    }

    func openGallery() {
        if galleryController == nil {
            galleryController = GalleryWindowController(store: store)
        }
        galleryController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher?.stop()
    }

    // MARK: - Private

    private func flashIcon() {
        DispatchQueue.main.async {
            self.menuBarIconName = "checkmark.circle.fill"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.menuBarIconName = "photo.stack"
            }
        }
    }

    @objc private func handleCopyLatest() {
        guard let latest = store.screenshots.first else { return }
        if ClipboardManager.copy(screenshot: latest) { flashIcon() }
    }

    @objc private func handleOpenGallery() {
        openGallery()
    }
}
