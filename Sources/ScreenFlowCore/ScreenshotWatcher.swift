import Foundation
import CoreServices

/// Watches the screenshot directory via FSEvents and fires `onNewScreenshot`
/// when a new screenshot file appears. Detection latency is ~300–500ms, far
/// faster than Finder's refresh rate.
public class ScreenshotWatcher {
    public let directory: URL
    public var onNewScreenshot: ((Screenshot) -> Void)?

    private weak var store: ScreenshotStore?
    private var streamRef: FSEventStreamRef?
    private var knownPaths: Set<String> = []
    private var isRunning = false

    public init(store: ScreenshotStore) {
        self.directory = store.directory
        self.store = store
        // Seed known paths from the filesystem directly to avoid races with
        // the store's async initial load.
        let existing = (try? FileManager.default.contentsOfDirectory(
            at: store.directory,
            includingPropertiesForKeys: nil
        )) ?? []
        self.knownPaths = Set(existing.map(\.path))
    }

    public func start() {
        guard streamRef == nil else { return }
        isRunning = true

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, contextInfo, _, eventPathsPointer, _, _ in
            guard let contextInfo else { return }
            let watcher = Unmanaged<ScreenshotWatcher>.fromOpaque(contextInfo)
                .takeUnretainedValue()
            // eventPaths is non-nullable (void*); with kFSEventStreamCreateFlagUseCFTypes
            // it points to a CFArray of CFStrings.
            let paths = Unmanaged<CFArray>.fromOpaque(eventPathsPointer)
                .takeUnretainedValue() as! [String]
            watcher.handleEvents(paths: paths)
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [directory.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
            )
        ) else { return }

        streamRef = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    public func stop() {
        isRunning = false
        guard let stream = streamRef else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        streamRef = nil
    }

    private func handleEvents(paths: [String]) {
        for path in paths {
            guard !knownPaths.contains(path) else { continue }
            let url = URL(fileURLWithPath: path)
            guard let store, store.isScreenshot(url) else { continue }

            // Small additional delay to ensure the file is fully flushed to disk
            // before we try to read it into the clipboard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.isRunning else { return }
                guard FileManager.default.fileExists(atPath: path) else { return }
                guard let attrs = try? url.resourceValues(forKeys: [.creationDateKey]),
                      let date = attrs.creationDate else { return }
                let screenshot = Screenshot(url: url, createdAt: date)
                self.knownPaths.insert(path)
                store.prepend(screenshot)
                self.onNewScreenshot?(screenshot)
            }
        }
    }

    deinit { stop() }
}
