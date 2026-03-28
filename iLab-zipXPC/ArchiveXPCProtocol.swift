import Foundation

/// XPC 通信协议
@objc protocol ArchiveXPCProtocol {
    /// 压缩为 7z 格式
    func compressTo7z(files: [String], outputPath: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 压缩为 ZIP 格式
    func compressToZip(files: [String], outputPath: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 解压到当前文件夹
    func extractHere(archivePath: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 解压到指定位置
    func extractTo(archivePath: String, destinationPath: String, withReply reply: @escaping (Bool, String?) -> Void)
}
