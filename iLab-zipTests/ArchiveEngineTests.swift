import XCTest
@testable import iLab_zip

final class ArchiveEngineTests: XCTestCase {
    
    // MARK: - 进度行解析
    
    func testParseProgressLineWithPercentage() {
        let line = "  45% 12 - src/main.swift"
        let progress = ArchiveEngine.parseProgressLine(line)
        
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.percentage, 45)
        XCTAssertEqual(progress?.currentFile, "src/main.swift")
    }
    
    func testParseProgressLineWithPercentageOnly() {
        let line = "  78%"
        let progress = ArchiveEngine.parseProgressLine(line)
        
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.percentage, 78)
        XCTAssertNil(progress?.currentFile)
    }
    
    func testParseProgressLineWithHundredPercent() {
        let line = "100%"
        let progress = ArchiveEngine.parseProgressLine(line)
        
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.percentage, 100)
    }
    
    func testParseProgressLineWithNonProgressLine() {
        let line = "Processing archive: test.7z"
        let progress = ArchiveEngine.parseProgressLine(line)
        
        XCTAssertNil(progress)
    }
    
    // MARK: - 错误映射
    
    func testErrorFromExitCode2WrongPassword() {
        let error = ArchiveError.from(exitCode: 2, stderr: "ERROR: Wrong password")
        if case .wrongPassword = error { } else {
            XCTFail("Expected wrongPassword, got \(error)")
        }
    }
    
    func testErrorFromExitCode2Corrupted() {
        let error = ArchiveError.from(exitCode: 2, stderr: "ERROR: Data error")
        if case .corruptedFile = error { } else {
            XCTFail("Expected corruptedFile, got \(error)")
        }
    }
    
    func testErrorFromExitCode255Cancelled() {
        let error = ArchiveError.from(exitCode: 255, stderr: "")
        if case .cancelled = error { } else {
            XCTFail("Expected cancelled, got \(error)")
        }
    }
}
