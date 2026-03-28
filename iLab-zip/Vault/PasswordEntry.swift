import Foundation
import GRDB

/// 密码条目模型
struct PasswordEntry: Identifiable, Codable, FetchableRecord, PersistableRecord, TableRecord {
    static let databaseTableName = "passwords"
    
    var id: Int64?
    var label: String?
    var cipher: Data
    var usedAt: Date?
    var createdAt: Date
    
    /// 解密后的密码（非持久化属性）
    var plaintext: String? {
        try? CryptoHelper.shared.decrypt(cipher: cipher)
    }
    
    enum Columns: String, ColumnExpression {
        case id, label, cipher, usedAt, createdAt
    }
}
