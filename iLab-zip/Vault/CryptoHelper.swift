import Foundation
import CryptoKit

/// 加密工具 — 使用 AES-256-GCM 加密密码
final class CryptoHelper {
    
    /// 共享实例
    static let shared = CryptoHelper()
    
    /// 对称密钥（由设备 UUID 通过 HKDF 派生）
    private let key: SymmetricKey
    
    private init() {
        // 获取设备硬件 UUID
        let deviceUUID = CryptoHelper.getDeviceUUID()
        let salt = "com.ilab.iLab-zip.vault".data(using: .utf8)!
        let inputKey = SymmetricKey(data: deviceUUID.data(using: .utf8) ?? Data(count: 32))
        
        // HKDF 派生 256-bit 密钥
        self.key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: "password-vault-key".data(using: .utf8)!,
            outputByteCount: 32
        )
    }
    
    /// AES-256-GCM 加密
    func encrypt(plaintext: String) throws -> Data {
        let data = plaintext.data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined!
    }
    
    /// AES-256-GCM 解密
    func decrypt(cipher: Data) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: cipher)
        let data = try AES.GCM.open(sealedBox, using: key)
        return String(data: data, encoding: .utf8)!
    }
    
    /// 获取设备硬件 UUID
    private static func getDeviceUUID() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        
        if let uuid = IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return uuid
        }
        
        // 回退方案：使用 Host UUID
        return ProcessInfo.processInfo.hostName
    }
}
