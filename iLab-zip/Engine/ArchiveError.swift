import Foundation

/// 压缩/解压操作错误类型
enum ArchiveError: LocalizedError {
    case wrongPassword
    case corruptedFile
    case insufficientDisk
    case volumeMissing(parts: [String])
    case unsupportedFormat
    case engineNotFound
    case cancelled
    case processError(exitCode: Int32, message: String)
    
    var errorDescription: String? {
        switch self {
        case .wrongPassword:
            return NSLocalizedString("error.wrongPassword", comment: "密码错误")
        case .corruptedFile:
            return NSLocalizedString("error.corruptedFile", comment: "文件损坏")
        case .insufficientDisk:
            return NSLocalizedString("error.insufficientDisk", comment: "磁盘空间不足")
        case .volumeMissing(let parts):
            let list = parts.joined(separator: ", ")
            return String(format: NSLocalizedString("error.volumeMissing", comment: "缺失分卷"), list)
        case .unsupportedFormat:
            return NSLocalizedString("error.unsupportedFormat", comment: "不支持的格式")
        case .engineNotFound:
            return NSLocalizedString("error.engineNotFound", comment: "压缩引擎未找到")
        case .cancelled:
            return NSLocalizedString("error.cancelled", comment: "操作已取消")
        case .processError(let code, let message):
            return "7zz exit code \(code): \(message)"
        }
    }
    
    /// 从 7zz 退出码映射到错误类型
    static func from(exitCode: Int32, stderr: String) -> ArchiveError {
        switch exitCode {
        case 0:
            fatalError("Should not create error from exit code 0")
        case 1:
            // Warning (Non fatal error)
            return .processError(exitCode: exitCode, message: stderr)
        case 2:
            // Fatal error
            if stderr.lowercased().contains("wrong password") ||
               stderr.lowercased().contains("cannot open encrypted") {
                return .wrongPassword
            }
            if stderr.lowercased().contains("no space") ||
               stderr.lowercased().contains("disk full") {
                return .insufficientDisk
            }
            return .corruptedFile
        case 7:
            // Command line error
            return .processError(exitCode: exitCode, message: stderr)
        case 8:
            // Not enough memory
            return .insufficientDisk
        case 255:
            // User stopped the process
            return .cancelled
        default:
            return .processError(exitCode: exitCode, message: stderr)
        }
    }
}
