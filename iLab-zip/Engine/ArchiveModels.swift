import Foundation

// MARK: - 压缩格式

enum ArchiveFormat: String, CaseIterable, Identifiable {
    case sevenZip = "7z"
    case zip = "zip"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip: return "ZIP"
        }
    }
}

// MARK: - 压缩选项

struct CompressionOptions {
    var format: ArchiveFormat = .sevenZip
    var level: Int = 5                    // 1-9
    var password: String?
    var encryptFilenames: Bool = false     // 仅 7z 支持 -mhe=on
    var volumeSize: VolumeSize = .none    // 分卷大小
    
    enum VolumeSize: Equatable, Hashable {
        case none
        case preset(megabytes: Int)       // 100, 500, 1024, 2048, 4096
        case custom(megabytes: Int)
        
        var megabytes: Int? {
            switch self {
            case .none: return nil
            case .preset(let mb): return mb
            case .custom(let mb): return mb
            }
        }
        
        static let presets: [(String, VolumeSize)] = [
            ("无分卷", .none),
            ("100 MB", .preset(megabytes: 100)),
            ("500 MB", .preset(megabytes: 500)),
            ("1 GB", .preset(megabytes: 1024)),
            ("2 GB", .preset(megabytes: 2048)),
            ("4 GB", .preset(megabytes: 4096)),
        ]
    }
}

// MARK: - 压缩包内条目

struct ArchiveEntry: Identifiable, Hashable {
    let id = UUID()
    let path: String                      // 完整路径（如 "src/main.swift"）
    let name: String                      // 文件名
    let size: UInt64                      // 原始大小
    let compressedSize: UInt64            // 压缩后大小
    let modifiedDate: Date?
    let isDirectory: Bool
    let isEncrypted: Bool
    let crc: String?
    
    /// 从路径中提取父目录
    var parentPath: String? {
        let components = path.split(separator: "/").dropLast()
        return components.isEmpty ? nil : components.joined(separator: "/")
    }
}

// MARK: - 进度状态

struct ArchiveProgress {
    let phase: Phase
    let percentage: Double                // 0.0 - 100.0
    let currentFile: String?
    let bytesProcessed: UInt64
    let totalBytes: UInt64
    let speed: Double?                    // bytes/sec
    
    enum Phase {
        case preparing
        case processing
        case finishing
        case completed
        case failed(Error)
        case cancelled
    }
    
    var estimatedTimeRemaining: TimeInterval? {
        guard let speed = speed, speed > 0, totalBytes > bytesProcessed else { return nil }
        return Double(totalBytes - bytesProcessed) / speed
    }
}

// MARK: - 文件树节点

class FileTreeNode: Identifiable, ObservableObject {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    var entry: ArchiveEntry?
    var children: [FileTreeNode] = []
    
    init(name: String, path: String, isDirectory: Bool, entry: ArchiveEntry? = nil) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.entry = entry
    }
}
