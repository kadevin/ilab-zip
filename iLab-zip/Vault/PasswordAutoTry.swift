import Foundation

/// 密码自动尝试 — 协调 ArchiveEngine 和 PasswordVault
final class PasswordAutoTry {
    
    private let engine: ArchiveEngine
    private let vault: PasswordVault
    
    init(engine: ArchiveEngine, vault: PasswordVault = .shared) {
        self.engine = engine
        self.vault = vault
    }
    
    /// 自动尝试结果
    enum Result {
        case notEncrypted               // 不需要密码
        case found(password: String)    // 找到匹配密码
        case notFound                   // 密码库中无匹配
    }
    
    /// 自动尝试密码库中的所有密码
    /// - Parameter archive: 压缩包路径
    /// - Returns: 尝试结果
    func tryPasswords(for archive: URL) async -> Result {
        // 1. 检测是否加密
        let encrypted = await engine.isEncrypted(archive: archive)
        guard encrypted else { return .notEncrypted }
        
        // 2. 获取密码列表（按最近使用时间排序）
        guard let passwords = try? vault.passwordsOrderedByUsage() else {
            return .notFound
        }
        
        // 3. 逐一尝试
        for entry in passwords {
            do {
                let success = try await engine.testIntegrity(of: archive, password: entry.plaintext)
                if success {
                    // 更新最后使用时间
                    try? vault.markUsed(id: entry.id)
                    return .found(password: entry.plaintext)
                }
            } catch {
                continue
            }
        }
        
        return .notFound
    }
}
