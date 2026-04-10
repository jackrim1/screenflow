import Foundation
import Combine

public class ScreenshotStore: ObservableObject {
    @Published public private(set) var screenshots: [Screenshot] = []

    public let directory: URL
    private let fileManager: FileManager

    public init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? ScreenshotStore.defaultScreenshotDirectory()
        load()
    }

    public func load() {
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let loaded = contents
            .filter { isScreenshot($0) }
            .compactMap { url -> Screenshot? in
                guard let attrs = try? url.resourceValues(forKeys: [.creationDateKey]),
                      let date = attrs.creationDate else { return nil }
                return Screenshot(url: url, createdAt: date)
            }
            .sorted { $0.createdAt > $1.createdAt }

        DispatchQueue.main.async {
            self.screenshots = loaded
        }
    }

    /// Insert a newly detected screenshot at the front, deduplicating by URL.
    public func prepend(_ screenshot: Screenshot) {
        DispatchQueue.main.async {
            self.screenshots.removeAll { $0.url == screenshot.url }
            self.screenshots.insert(screenshot, at: 0)
        }
    }

    /// Returns true if the URL looks like a macOS screenshot file.
    public func isScreenshot(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ext == "png" || ext == "jpg" || ext == "jpeg" else { return false }
        let name = url.lastPathComponent
        return name.hasPrefix("Screenshot")      // macOS 10.14+
            || name.hasPrefix("Screen Shot")     // older macOS
            || name.hasPrefix("CleanShot")       // CleanShot X
    }

    // MARK: - Static helpers

    public static func defaultScreenshotDirectory() -> URL {
        let prefs = UserDefaults(suiteName: "com.apple.screencapture")
        if let path = prefs?.string(forKey: "location"), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
    }
}
