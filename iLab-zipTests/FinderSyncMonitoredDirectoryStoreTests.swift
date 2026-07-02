import XCTest
@testable import iLab_zip

final class FinderSyncMonitoredDirectoryStoreTests: XCTestCase {

    func testStorePersistsAndDeduplicatesStandardizedDirectoryURLs() throws {
        let fileURL = temporaryConfigFileURL()
        let store = FinderSyncMonitoredDirectoryStore(fileURL: fileURL)

        try store.save([
            URL(fileURLWithPath: "/Users/tester/Projects", isDirectory: true),
            URL(fileURLWithPath: "/Users/tester/Projects/../Projects", isDirectory: true)
        ])

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(store.directoryURLs(), [
            URL(fileURLWithPath: "/Users/tester/Projects", isDirectory: true)
        ])
    }

    func testStoreReturnsEmptyListWhenConfigFileIsMissing() throws {
        let store = FinderSyncMonitoredDirectoryStore(fileURL: temporaryConfigFileURL())

        XCTAssertEqual(store.directoryURLs(), [])
    }

    func testStoreReturnsEmptyListWhenConfigFileIsInvalid() throws {
        let fileURL = temporaryConfigFileURL()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)

        let store = FinderSyncMonitoredDirectoryStore(fileURL: fileURL)

        XCTAssertEqual(store.directoryURLs(), [])
    }

    private func temporaryConfigFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinderSyncMonitoredDirectoryStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("FinderSyncConfig.json")
    }
}
