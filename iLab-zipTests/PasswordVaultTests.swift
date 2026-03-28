import XCTest
@testable import iLab_zip

final class PasswordVaultTests: XCTestCase {
    
    var vault: PasswordVault!
    
    override func setUp() async throws {
        vault = try PasswordVault(inMemory: true)
    }
    
    func testAddAndRetrievePassword() throws {
        let entry = try vault.addPassword(label: "Test", plaintext: "mypassword123")
        
        let all = try vault.allPasswords()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.plaintext, "mypassword123")
        XCTAssertEqual(all.first?.label, "Test")
    }
    
    func testDeletePassword() throws {
        let entry = try vault.addPassword(plaintext: "password1")
        let id = entry.id!
        
        try vault.removePassword(id: id)
        
        let count = try vault.count()
        XCTAssertEqual(count, 0)
    }
    
    func testUpdateLabel() throws {
        let entry = try vault.addPassword(plaintext: "password1")
        let id = entry.id!
        
        try vault.updateLabel(id: id, label: "Updated Label")
        
        let all = try vault.allPasswords()
        XCTAssertEqual(all.first?.label, "Updated Label")
    }
    
    func testPasswordsOrderedByUsage() throws {
        let entry1 = try vault.addPassword(label: "Old", plaintext: "pass1")
        let entry2 = try vault.addPassword(label: "New", plaintext: "pass2")
        
        // 标记 entry1 为刚使用过
        try vault.markUsed(id: entry1.id!)
        
        let ordered = try vault.passwordsOrderedByUsage()
        XCTAssertEqual(ordered.first?.plaintext, "pass1") // 最近使用的排在前面
    }
    
    func testEncryptionRoundTrip() throws {
        let original = "超级复杂的密码!@#$%^&*()"
        let cipher = try CryptoHelper.shared.encrypt(plaintext: original)
        let decrypted = try CryptoHelper.shared.decrypt(cipher: cipher)
        XCTAssertEqual(original, decrypted)
    }
    
    func testMultiplePasswords() throws {
        for i in 1...5 {
            try vault.addPassword(label: "Pass \(i)", plaintext: "password\(i)")
        }
        
        let count = try vault.count()
        XCTAssertEqual(count, 5)
    }
}
