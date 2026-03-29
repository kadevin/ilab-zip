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
    func tryPasswords(for archive: URL) async -> Result {
        // 1. 用 listContents（空密码）快速检测是否加密
        //    listContents 只读取 header，对大文件也是即时返回
        do {
            NSLog("[iLab-zip] PasswordAutoTry: checking encryption with listContents...")
            let entries = try await engine.listContents(of: archive, password: nil)
            NSLog("[iLab-zip] PasswordAutoTry: listContents returned %d entries", entries.count)
            let hasEncrypted = entries.contains { $0.isEncrypted }
            if !hasEncrypted {
                NSLog("[iLab-zip] PasswordAutoTry: NOT encrypted")
                return .notEncrypted
            }
            NSLog("[iLab-zip] PasswordAutoTry: IS encrypted")
        } catch {
            NSLog("[iLab-zip] PasswordAutoTry: listContents error (likely header-encrypted): %@", error.localizedDescription)
        }
        
        // 2. 获取密码列表（按最近使用时间排序）
        guard let passwords = try? vault.passwordsOrderedByUsage() else {
            return .notFound
        }
        
        // 3. 逐个尝试密码 — 用 listContents 快速验证，不用 testIntegrity
        for entry in passwords {
            do {
                let testEntries = try await engine.listContents(of: archive, password: entry.plaintext)
                // 如果能成功列出内容且没有错误，密码正确
                if !testEntries.isEmpty {
                    try? vault.markUsed(id: entry.id)
                    return .found(password: entry.plaintext)
                }
            } catch {
                // 密码错误，继续尝试下一个
                continue
            }
        }
        
        return .notFound
    }
}
