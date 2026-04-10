import AppKit
import ScreenFlowCore

// MARK: - Panel

class FloatingThumbnailPanel: NSPanel {
    private var dismissTimer: Timer?
    private static var current: FloatingThumbnailPanel?

    static func show(for screenshot: Screenshot) {
        current?.fadeOut(animated: false)
        guard let image = NSImage(contentsOf: screenshot.url) else { return }

        let size = panelSize(for: image.size)
        let panel = FloatingThumbnailPanel(screenshot: screenshot, image: image, size: size)
        current = panel
        panel.orderFrontRegardless()

        panel.dismissTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { _ in
            panel.fadeOut()
        }
    }

    /// Fit inside 300×260 while keeping EXACT aspect ratio.
    /// Derive height from the floored width so both dimensions share the same
    /// scale factor and there is no sub-pixel mismatch.
    private static func panelSize(for imageSize: NSSize) -> NSSize {
        let maxW: CGFloat = 300, maxH: CGFloat = 260
        let scale = min(maxW / imageSize.width, maxH / imageSize.height)
        let w = floor(imageSize.width * scale)
        let h = floor(w * imageSize.height / imageSize.width)   // derived, not independently floored
        return NSSize(width: w, height: h)
    }

    private init(screenshot: Screenshot, image: NSImage, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            setFrameOrigin(NSPoint(
                x: screen.frame.maxX - size.width - 16,
                y: screen.visibleFrame.minY + 16
            ))
        }

        contentView = ThumbnailContainerView(
            screenshot: screenshot, image: image, size: size,
            onDismiss: { [weak self] in self?.fadeOut() }
        )
    }

    func fadeOut(animated: Bool = true) {
        dismissTimer?.invalidate()
        guard animated else {
            orderOut(nil)
            if FloatingThumbnailPanel.current === self { FloatingThumbnailPanel.current = nil }
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            self.animator().alphaValue = 0
        } completionHandler: {
            self.orderOut(nil)
            if FloatingThumbnailPanel.current === self { FloatingThumbnailPanel.current = nil }
        }
    }
}

// MARK: - Container

private class ThumbnailContainerView: NSView {
    init(screenshot: Screenshot, image: NSImage, size: NSSize, onDismiss: @escaping () -> Void) {
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true

        // 1. Plain NSImageView for display — NOT subclassed, so its rendering is untouched.
        let iv = NSImageView(frame: bounds)
        iv.image = image
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.imageAlignment = .alignCenter
        iv.autoresizingMask = [.width, .height]
        addSubview(iv)

        // 2. Transparent overlay for drag — sits on top of the image view.
        let drag = DragOverlayView(frame: bounds, url: screenshot.url, image: image)
        drag.autoresizingMask = [.width, .height]
        addSubview(drag)

        // 3. "Drag to paste" label
        let label = NSTextField(labelWithString: "Drag to paste")
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.backgroundColor = NSColor.black.withAlphaComponent(0.45)
        label.drawsBackground = true
        label.isBezeled = false
        label.sizeToFit()
        let lw = label.frame.width + 12, lh = label.frame.height + 5
        label.frame = NSRect(x: floor((size.width - lw) / 2), y: 8, width: lw, height: lh)
        label.wantsLayer = true
        label.layer?.cornerRadius = lh / 2
        label.layer?.masksToBounds = true
        addSubview(label)

        // 4. Close button
        let btn = NSButton(frame: NSRect(x: size.width - 24, y: size.height - 24, width: 20, height: 20))
        btn.isBordered = false
        btn.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Dismiss")
        btn.contentTintColor = .white
        btn.target = self
        btn.action = #selector(close)
        addSubview(btn)

        self.onDismiss = onDismiss
    }
    required init?(coder: NSCoder) { fatalError() }

    private var onDismiss: (() -> Void)?
    @objc private func close() { onDismiss?() }
}

// MARK: - Drag overlay

/// Transparent NSView that sits on top of the image view and handles drag.
/// Keeping drag and display separate means NSImageView's rendering is never touched.
private class DragOverlayView: NSView, NSDraggingSource {
    private let url: URL
    private let image: NSImage

    init(frame: NSRect, url: URL, image: NSImage) {
        self.url = url
        self.image = image
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    // Transparent — let the image view underneath show through
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {}

    override func mouseDown(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if let data = try? Data(contentsOf: url) {
            item.setData(data, forType: NSPasteboard.PasteboardType("public.png"))
        }
        let di = NSDraggingItem(pasteboardWriter: item)
        di.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [di], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}
