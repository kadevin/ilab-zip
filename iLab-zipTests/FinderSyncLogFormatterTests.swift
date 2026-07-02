import XCTest
@testable import iLab_zip

final class FinderSyncLogFormatterTests: XCTestCase {

    func testItemSummaryDoesNotExposePathsOrFilenames() {
        let summary = FinderSyncLogFormatter.itemSummary([
            URL(fileURLWithPath: "/Users/tester/Secret Client/archive.zip"),
            URL(fileURLWithPath: "/Volumes/Private/roadmap.7z")
        ])

        XCTAssertEqual(summary, "count=2, extensions=7z,zip")
        XCTAssertFalse(summary.contains("/Users/tester"))
        XCTAssertFalse(summary.contains("Secret Client"))
        XCTAssertFalse(summary.contains("roadmap"))
    }

    func testCommandSummaryDoesNotExposeURL() {
        let summary = FinderSyncLogFormatter.commandSummary(
            action: "extractto",
            fileCount: 1,
            hasDestination: true
        )

        XCTAssertEqual(summary, "action=extractto, fileCount=1, hasDestination=true")
    }
}
