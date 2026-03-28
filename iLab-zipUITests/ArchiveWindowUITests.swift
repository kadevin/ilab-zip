import XCTest
import SwiftUI
@testable import iLab_zip

final class ArchiveWindowUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    func testMainWindowExists() throws {
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
    
    func testToolbarButtonsExist() throws {
        let toolbar = app.toolbars.firstMatch
        XCTAssertTrue(toolbar.exists)
    }
}
