import Foundation
import GRDB

/// 密码库 — 管理本地加密密码存储
final class PasswordVault {
    
    /// 共享实例
    static let shared: PasswordVault = {
        try! PasswordVault()
    }()
    
    private let dbQueue: DatabaseQueue
    
    init() throws {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vaultDir = appSupportDir.appendingPathComponent("iLab-zip")
        try FileManager.default.createDirectory(at: vaultDir, withIntermediateDirectories: true)
        
        let dbPath = vaultDir.appendingPathComponent("vault.db").path
        dbQueue = try DatabaseQueue(path: dbPath)
        
        try migrate()
    }
    
    /// 用于测试：内存数据库
    init(inMemory: Bool) throws {
        dbQueue = try DatabaseQueue()
        try migrate()
    }
    
    // MARK: - 数据库迁移
    
    private func migrate() throws {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1_createPasswords") { db in
            try db.create(table: "passwords", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("label", .text)
                t.column("cipher", .blob).notNull()
                t.column("usedAt", .datetime)
                t.column("createdAt", .datetime).notNull().defaults(to: Date())
            }
        }
        
        try migrator.migrate(dbQueue)
    }
    
    // MARK: - CRUD 操作
    
    /// 添加密码
    @discardableResult
    func addPassword(label: String? = nil, plaintext: String) throws -> PasswordEntry {
        let cipher = try CryptoHelper.shared.encrypt(plaintext: plaintext)
        let record = try dbQueue.write { db in
            try PasswordEntry(
                id: nil,
                label: label,
                cipher: cipher,
                usedAt: nil,
                createdAt: Date()
            ).inserted(db)
        }
        return record
    }
    
    /// 删除密码
    func removePassword(id: Int64) throws {
        try dbQueue.write { db in
            _ = try PasswordEntry.deleteOne(db, id: id)
        }
    }
    
    /// 更新备注
    func updateLabel(id: Int64, label: String) throws {
        try dbQueue.write { db in
            if var entry = try PasswordEntry.fetchOne(db, id: id) {
                entry.label = label
                try entry.update(db)
            }
        }
    }
    
    /// 获取所有密码条目
    func allPasswords() throws -> [PasswordEntry] {
        try dbQueue.read { db in
            try PasswordEntry.order(PasswordEntry.Columns.createdAt.desc).fetchAll(db)
        }
    }
    
    /// 按最后使用时间排序获取所有明文密码（用于自动尝试）
    func passwordsOrderedByUsage() throws -> [(id: Int64, plaintext: String)] {
        let entries = try dbQueue.read { db in
            try PasswordEntry.order(PasswordEntry.Columns.usedAt.desc).fetchAll(db)
        }
        return entries.compactMap { entry in
            guard let id = entry.id, let plaintext = entry.plaintext else { return nil }
            return (id: id, plaintext: plaintext)
        }
    }
    
    /// 标记密码为刚使用过
    func markUsed(id: Int64) throws {
        try dbQueue.write { db in
            if var entry = try PasswordEntry.fetchOne(db, id: id) {
                entry.usedAt = Date()
                try entry.update(db)
            }
        }
    }
    
    /// 密码总数
    func count() throws -> Int {
        try dbQueue.read { db in
            try PasswordEntry.fetchCount(db)
        }
    }
}
