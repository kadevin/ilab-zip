import XCTest
@testable import iLab_zip

final class FinderExtensionHandoffTests: XCTestCase {

    func testWriteURLContainsOnlyOpaqueHandoffIdentifier() throws {
        let store = makeStore()

        let handoff = FinderExtensionHandoff(
            action: "compress7z",
            files: [
                "/Users/tester/Secret Client/a.zip",
                "/Users/tester/100% done.zip"
            ],
            dest: "/Users/tester/output"
        )

        let url = try store.writeURL(for: handoff)

        XCTAssertEqual(url.scheme, "ilabzip")
        XCTAssertEqual(url.host, "handoff")
        XCTAssertFalse(url.absoluteString.contains("Secret"))
        XCTAssertFalse(url.absoluteString.contains("/Users/tester"))
        XCTAssertNotNil(FinderExtensionCommand(url: url)?.handoffID)
    }

    func testReadDeletesHandoffAndPreservesPathsExactly() throws {
        let store = makeStore()
        let expected = FinderExtensionHandoff(
            action: "extractto",
            files: ["/Users/tester/a%20b.zip", "/Users/tester/100% done.zip"],
            dest: "/Users/tester/output%20folder"
        )
        let url = try store.writeURL(for: expected)
        let command = try XCTUnwrap(FinderExtensionCommand(url: url))

        let actual = try store.readAndDelete(id: try XCTUnwrap(command.handoffID))

        XCTAssertEqual(actual, expected)
        XCTAssertFalse(store.containsHandoff(id: command.handoffID!))
    }

    func testReadRejectsMissingHandoff() {
        let store = makeStore()

        XCTAssertThrowsError(try store.readAndDelete(id: UUID()))
    }

    private func makeStore() -> FinderExtensionHandoffStore {
        FinderExtensionHandoffStore(pasteboardPrefix: "FinderExtensionHandoffTests.\(UUID().uuidString).")
    }
}
