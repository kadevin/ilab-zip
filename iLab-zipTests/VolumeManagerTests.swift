import XCTest
@testable import iLab_zip

final class VolumeManagerTests: XCTestCase {
    
    func testIsVolumePartWith7zVolume() {
        let url = URL(fileURLWithPath: "/tmp/archive.7z.001")
        XCTAssertTrue(VolumeManager.isVolumePart(url))
    }
    
    func testIsVolumePartWithZipVolume() {
        let url = URL(fileURLWithPath: "/tmp/archive.zip.002")
        XCTAssertTrue(VolumeManager.isVolumePart(url))
    }
    
    func testIsVolumePartWithRarPart() {
        let url = URL(fileURLWithPath: "/tmp/archive.part1.rar")
        XCTAssertTrue(VolumeManager.isVolumePart(url))
    }
    
    func testIsVolumePartWithGenericNumberSuffix() {
        let url = URL(fileURLWithPath: "/tmp/archive.001")
        XCTAssertTrue(VolumeManager.isVolumePart(url))
    }
    
    func testIsVolumePartWithNormalFile() {
        let url = URL(fileURLWithPath: "/tmp/archive.7z")
        XCTAssertFalse(VolumeManager.isVolumePart(url))
    }
    
    func testIsVolumePartWithRegularZip() {
        let url = URL(fileURLWithPath: "/tmp/archive.zip")
        XCTAssertFalse(VolumeManager.isVolumePart(url))
    }
}
