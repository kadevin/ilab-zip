import XCTest
@testable import iLab_zip

final class FinderExtensionCommandTests: XCTestCase {

    func testParseRejectsDirectFileCommands() throws {
        var components = URLComponents()
        components.scheme = "ilabzip"
        components.host = "compress7z"
        components.queryItems = [
            URLQueryItem(name: "file", value: "/Users/tester/a%20b.zip"),
            URLQueryItem(name: "file", value: "/Users/tester/100% done.zip")
        ]

        XCTAssertNil(FinderExtensionCommand(url: try XCTUnwrap(components.url)))
    }

    func testParseRejectsDirectDestinationCommands() throws {
        var components = URLComponents()
        components.scheme = "ilabzip"
        components.host = "extractto"
        components.queryItems = [
            URLQueryItem(name: "file", value: "/Users/tester/archive.zip"),
            URLQueryItem(name: "dest", value: "/Users/tester/output%20folder")
        ]

        XCTAssertNil(FinderExtensionCommand(url: try XCTUnwrap(components.url)))
    }

    func testParseHandoffCommandCarriesOnlyIdentifier() throws {
        var components = URLComponents()
        components.scheme = "ilabzip"
        components.host = "handoff"
        components.queryItems = [
            URLQueryItem(name: "id", value: "B8A8F40A-2C23-48C5-A12E-C34852D8755D")
        ]

        let command = try XCTUnwrap(FinderExtensionCommand(url: XCTUnwrap(components.url)))

        XCTAssertEqual(command.action, "handoff")
        XCTAssertEqual(command.handoffID, UUID(uuidString: "B8A8F40A-2C23-48C5-A12E-C34852D8755D"))
        XCTAssertEqual(command.files, [])
        XCTAssertNil(command.dest)
    }

    func testParseHandoffCommandRejectsNonUUIDIdentifier() throws {
        var components = URLComponents()
        components.scheme = "ilabzip"
        components.host = "handoff"
        components.queryItems = [
            URLQueryItem(name: "id", value: "../archive-paths")
        ]

        XCTAssertNil(FinderExtensionCommand(url: try XCTUnwrap(components.url)))
    }
}
