import XCTest
@testable import ScreenFlowCore

final class ScreenshotWatcherTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenFlowWatcherTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Detection

    func test_detectsNewScreenshotFile() throws {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        let exp = expectation(description: "new screenshot detected")

        watcher.onNewScreenshot = { shot in
            XCTAssertEqual(shot.filename, "Screenshot detected.png")
            exp.fulfill()
        }

        watcher.start()

        // Give the FSEvent stream a moment to initialise before we write
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            try? "fake image".write(
                to: self.tempDir.appendingPathComponent("Screenshot detected.png"),
                atomically: true, encoding: .utf8
            )
        }

        waitForExpectations(timeout: 3)
        watcher.stop()
    }

    func test_ignoresNonScreenshotExtensions() throws {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        var called = false
        watcher.onNewScreenshot = { _ in called = true }

        watcher.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            try? "data".write(
                to: self.tempDir.appendingPathComponent("document.pdf"),
                atomically: true, encoding: .utf8
            )
        }

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exp.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertFalse(called)
        watcher.stop()
    }

    func test_ignoresFilesThatDontMatchScreenshotPrefix() throws {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        var called = false
        watcher.onNewScreenshot = { _ in called = true }

        watcher.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            try? "data".write(
                to: self.tempDir.appendingPathComponent("random_image.png"),
                atomically: true, encoding: .utf8
            )
        }

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exp.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertFalse(called)
        watcher.stop()
    }

    func test_newScreenshotIsPrepenedToStore() throws {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        let exp = expectation(description: "store updated")

        watcher.onNewScreenshot = { _ in
            DispatchQueue.main.async {
                if store.screenshots.first?.filename == "Screenshot store.png" {
                    exp.fulfill()
                }
            }
        }

        watcher.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            try? "fake".write(
                to: self.tempDir.appendingPathComponent("Screenshot store.png"),
                atomically: true, encoding: .utf8
            )
        }

        waitForExpectations(timeout: 3)
        watcher.stop()
    }

    // MARK: - Stop behaviour

    func test_stopPreventsSubsequentCallbacks() throws {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        var callCount = 0
        watcher.onNewScreenshot = { _ in callCount += 1 }

        watcher.start()
        watcher.stop()

        // Write a file after stopping — no callback should fire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            try? "data".write(
                to: self.tempDir.appendingPathComponent("Screenshot after_stop.png"),
                atomically: true, encoding: .utf8
            )
        }

        let exp = expectation(description: "wait")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { exp.fulfill() }
        waitForExpectations(timeout: 2)

        XCTAssertEqual(callCount, 0)
    }

    func test_startIsIdempotent() {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        // Calling start twice should not crash or create double streams
        watcher.start()
        watcher.start()
        watcher.stop()
    }

    func test_stopIsIdempotent() {
        let store = ScreenshotStore(directory: tempDir)
        let watcher = ScreenshotWatcher(store: store)
        watcher.start()
        watcher.stop()
        watcher.stop()  // Should not crash
    }
}
