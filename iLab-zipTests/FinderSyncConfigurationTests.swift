import XCTest
@testable import iLab_zip

final class FinderSyncConfigurationTests: XCTestCase {

    func testDefaultMonitoredDirectoriesAvoidBroadRoots() {
        let urls = FinderSyncConfiguration.defaultMonitoredDirectoryURLs(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true),
            existingDirectory: { _ in true }
        )

        XCTAssertFalse(urls.contains(URL(fileURLWithPath: "/", isDirectory: true)))
        XCTAssertFalse(urls.contains(URL(fileURLWithPath: "/Users/tester", isDirectory: true)))
    }

    func testDefaultMonitoredDirectoriesCoverCommonFinderLocations() {
        let urls = FinderSyncConfiguration.defaultMonitoredDirectoryURLs(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true),
            existingDirectory: { _ in true }
        )

        XCTAssertTrue(urls.contains(URL(fileURLWithPath: "/Users/tester/Desktop", isDirectory: true)))
        XCTAssertTrue(urls.contains(URL(fileURLWithPath: "/Users/tester/Documents", isDirectory: true)))
        XCTAssertTrue(urls.contains(URL(fileURLWithPath: "/Users/tester/Downloads", isDirectory: true)))
        XCTAssertTrue(urls.contains(URL(fileURLWithPath: "/Volumes", isDirectory: true)))
        XCTAssertTrue(urls.contains(URL(fileURLWithPath: "/Users/Shared", isDirectory: true)))
    }

    func testAdditionalMonitoredDirectoriesAreIncludedButBroadRootsAreRejected() {
        let urls = FinderSyncConfiguration.defaultMonitoredDirectoryURLs(
            homeDirectory: URL(fileURLWithPath: "/Users/tester", isDirectory: true),
            additionalDirectories: [
                URL(fileURLWithPath: "/Users/tester/Projects", isDirectory: true),
                URL(fileURLWithPath: "/Users/tester", isDirectory: true),
                URL(fileURLWithPath: "/", isDirectory: true)
            ],
            existingDirectory: { _ in true }
        )

        XCTAssertTrue(urls.contains(URL(fileURLWithPath: "/Users/tester/Projects", isDirectory: true)))
        XCTAssertFalse(urls.contains(URL(fileURLWithPath: "/Users/tester", isDirectory: true)))
        XCTAssertFalse(urls.contains(URL(fileURLWithPath: "/", isDirectory: true)))
    }
}
