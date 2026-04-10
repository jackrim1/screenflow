import XCTest
@testable import ScreenFlowCore

final class ScreenshotTests: XCTestCase {

    func test_filename_derivedFromURL() {
        let url = URL(fileURLWithPath: "/tmp/Screenshot 2024-01-15 at 10.30.00.png")
        let shot = Screenshot(url: url, createdAt: Date())
        XCTAssertEqual(shot.filename, "Screenshot 2024-01-15 at 10.30.00.png")
    }

    func test_equality_basedOnURL_notID() {
        let url = URL(fileURLWithPath: "/tmp/screenshot.png")
        let a = Screenshot(url: url, createdAt: Date())
        let b = Screenshot(url: url, createdAt: Date())
        // Two instances from the same URL should be equal (same file)
        XCTAssertEqual(a, b)
        // But they get unique IDs (so both can coexist in collections without collisions)
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_differentURLs_notEqual() {
        let a = Screenshot(url: URL(fileURLWithPath: "/tmp/a.png"), createdAt: Date())
        let b = Screenshot(url: URL(fileURLWithPath: "/tmp/b.png"), createdAt: Date())
        XCTAssertNotEqual(a, b)
    }

    func test_hashable_byURL() {
        let url = URL(fileURLWithPath: "/tmp/shot.png")
        let a = Screenshot(url: url, createdAt: Date())
        let b = Screenshot(url: url, createdAt: Date())
        // Both should map to the same bucket in a Set
        var set = Set<Screenshot>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }
}
