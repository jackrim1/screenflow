import XCTest
import AppKit
@testable import ScreenFlowCore

final class ClipboardManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        NSPasteboard.general.clearContents()
    }

    // MARK: - copy(imageAt:)

    func test_copyNonExistentFile_returnsFalse() {
        let url = URL(fileURLWithPath: "/tmp/no_such_file_\(UUID().uuidString).png")
        XCTAssertFalse(ClipboardManager.copy(imageAt: url))
    }

    func test_copyValidImage_returnsTrue() throws {
        let url = try makeTestImage()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(ClipboardManager.copy(imageAt: url))
    }

    func test_copyValidImage_setsClipboard() throws {
        let url = try makeTestImage()
        defer { try? FileManager.default.removeItem(at: url) }

        _ = ClipboardManager.copy(imageAt: url)
        XCTAssertTrue(ClipboardManager.hasImage())
    }

    func test_copyValidImage_incrementsChangeCount() throws {
        let url = try makeTestImage()
        defer { try? FileManager.default.removeItem(at: url) }

        let before = ClipboardManager.currentChangeCount()
        _ = ClipboardManager.copy(imageAt: url)
        XCTAssertGreaterThan(ClipboardManager.currentChangeCount(), before)
    }

    // MARK: - copy(screenshot:)

    func test_copyScreenshot_copiesFromURL() throws {
        let url = try makeTestImage()
        defer { try? FileManager.default.removeItem(at: url) }

        let shot = Screenshot(url: url, createdAt: Date())
        XCTAssertTrue(ClipboardManager.copy(screenshot: shot))
        XCTAssertTrue(ClipboardManager.hasImage())
    }

    // MARK: - hasImage

    func test_hasImage_falseOnEmptyPasteboard() {
        XCTAssertFalse(ClipboardManager.hasImage())
    }

    func test_hasImage_trueAfterImageCopied() throws {
        let url = try makeTestImage()
        defer { try? FileManager.default.removeItem(at: url) }
        _ = ClipboardManager.copy(imageAt: url)
        XCTAssertTrue(ClipboardManager.hasImage())
    }

    // MARK: - Second copy clears previous image

    func test_secondCopy_replacesPrevious() throws {
        let url1 = try makeTestImage(color: .red)
        let url2 = try makeTestImage(color: .blue)
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        _ = ClipboardManager.copy(imageAt: url1)
        let countAfterFirst = ClipboardManager.currentChangeCount()

        _ = ClipboardManager.copy(imageAt: url2)
        XCTAssertGreaterThan(ClipboardManager.currentChangeCount(), countAfterFirst)
        XCTAssertTrue(ClipboardManager.hasImage())
    }

    // MARK: - Helpers

    private func makeTestImage(color: NSColor = .systemTeal) throws -> URL {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        color.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { throw CocoaError(.fileWriteUnknown) }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sftest_\(UUID().uuidString).png")
        try png.write(to: url)
        return url
    }
}
