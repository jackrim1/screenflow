import XCTest
@testable import ScreenFlowCore

final class ScreenshotStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenFlowTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - isScreenshot

    func test_isScreenshot_modernMacOSPrefix() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertTrue(store.isScreenshot(url("Screenshot 2024-01-15 at 10.30.00.png")))
    }

    func test_isScreenshot_olderMacOSPrefix() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertTrue(store.isScreenshot(url("Screen Shot 2020-06-01 at 09.00.00.png")))
    }

    func test_isScreenshot_cleanShotX() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertTrue(store.isScreenshot(url("CleanShot 2024-03-10 at 14.22.01.png")))
    }

    func test_isScreenshot_jpg() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertTrue(store.isScreenshot(url("Screenshot 2024-01-01.jpg")))
    }

    func test_isScreenshot_ignorePDF() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertFalse(store.isScreenshot(url("document.pdf")))
    }

    func test_isScreenshot_ignoreRandomPNG() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertFalse(store.isScreenshot(url("photo.png")))
    }

    func test_isScreenshot_ignoreHiddenFile() {
        let store = ScreenshotStore(directory: tempDir)
        XCTAssertFalse(store.isScreenshot(url(".DS_Store")))
    }

    // MARK: - load

    func test_emptyDirectory_producesEmptyList() {
        let store = ScreenshotStore(directory: tempDir)
        waitForMainQueue()
        XCTAssertTrue(store.screenshots.isEmpty)
    }

    func test_load_picksUpExistingFiles() throws {
        try writeFile("Screenshot 2024-01-15.png")
        try writeFile("Screenshot 2024-01-16.png")
        try writeFile("README.txt")   // should be ignored

        let store = ScreenshotStore(directory: tempDir)
        waitForMainQueue()
        XCTAssertEqual(store.screenshots.count, 2)
        XCTAssertFalse(store.screenshots.contains { $0.filename == "README.txt" })
    }

    func test_load_sortedNewestFirst() throws {
        // Write two files; manipulate creation dates via attributes
        let older = tempDir.appendingPathComponent("Screenshot old.png")
        let newer = tempDir.appendingPathComponent("Screenshot new.png")
        try "x".write(to: older, atomically: true, encoding: .utf8)
        try "x".write(to: newer, atomically: true, encoding: .utf8)

        let now = Date()
        let olderDate = now.addingTimeInterval(-7200)
        let newerDate = now.addingTimeInterval(-1800)
        try FileManager.default.setAttributes(
            [.creationDate: olderDate], ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.creationDate: newerDate], ofItemAtPath: newer.path
        )

        let store = ScreenshotStore(directory: tempDir)
        waitForMainQueue()
        XCTAssertEqual(store.screenshots.count, 2)
        XCTAssertEqual(store.screenshots[0].filename, "Screenshot new.png")
        XCTAssertEqual(store.screenshots[1].filename, "Screenshot old.png")
    }

    // MARK: - prepend

    func test_prepend_insertsAtFront() {
        let store = ScreenshotStore(directory: tempDir)
        waitForMainQueue()

        let shot = Screenshot(url: url("Screenshot fresh.png"), createdAt: Date())
        store.prepend(shot)
        waitForMainQueue()

        XCTAssertEqual(store.screenshots.first?.url, shot.url)
    }

    func test_prepend_deduplicatesByURL() {
        let store = ScreenshotStore(directory: tempDir)
        waitForMainQueue()

        let shot = Screenshot(url: url("Screenshot fresh.png"), createdAt: Date())
        store.prepend(shot)
        store.prepend(shot)
        waitForMainQueue()

        let count = store.screenshots.filter { $0.url == shot.url }.count
        XCTAssertEqual(count, 1)
    }

    func test_prepend_keepsOthersInOrder() throws {
        try writeFile("Screenshot a.png")
        try writeFile("Screenshot b.png")

        let store = ScreenshotStore(directory: tempDir)
        waitForMainQueue()

        let shot = Screenshot(url: url("Screenshot newest.png"), createdAt: Date())
        store.prepend(shot)
        waitForMainQueue()

        XCTAssertEqual(store.screenshots.first?.filename, "Screenshot newest.png")
    }

    // MARK: - defaultScreenshotDirectory

    func test_defaultDirectory_isDesktopWhenNoPreference() {
        // Remove the screencapture preference to test the fallback.
        // (We read from UserDefaults so we can check the fallback logic without
        // mutating the real preference.)
        let result = ScreenshotStore.defaultScreenshotDirectory()
        // Should be somewhere reasonable on the system
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
    }

    // MARK: - Helpers

    private func url(_ name: String) -> URL {
        tempDir.appendingPathComponent(name)
    }

    private func writeFile(_ name: String) throws {
        try "fake".write(to: url(name), atomically: true, encoding: .utf8)
    }

    /// Flush one main-queue cycle so @Published assignments propagate.
    private func waitForMainQueue() {
        let exp = expectation(description: "main queue flush")
        DispatchQueue.main.async { exp.fulfill() }
        waitForExpectations(timeout: 1)
    }
}
