import Foundation

/// 分卷压缩/解压管理器
struct VolumeManager {
    
    // MARK: - 分卷文件模式
    
    /// 识别的分卷文件后缀模式
    private static let volumePatterns: [(regex: String, firstSuffix: String)] = [
        // 7z 分卷: .7z.001, .7z.002, ...
        (#"\.7z\.(\d{3})$"#, ".7z.001"),
        // ZIP 分卷: .zip.001, .zip.002, ...
        (#"\.zip\.(\d{3})$"#, ".zip.001"),
        // ZIP 分卷: .z01, .z02, ... (主文件为 .zip)
        (#"\.z(\d{2})$"#, ".z01"),
        // RAR 分卷 (新): .part1.rar, .part2.rar, ...
        (#"\.part(\d+)\.rar$"#, ".part1.rar"),
        // RAR 分卷 (旧): .rar, .r00, .r01, ...
        (#"\.r(\d{2})$"#, ".r00"),
        // 通用数字后缀: .001, .002, ...
        (#"\.(\d{3})$"#, ".001"),
    ]
    
    /// 检测文件是否为分卷文件
    static func isVolumePart(_ url: URL) -> Bool {
        let filename = url.lastPathComponent
        return volumePatterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern.regex))?.firstMatch(
                in: filename,
                range: NSRange(filename.startIndex..., in: filename)
            ) != nil
        }
    }
    
    /// 查找第一分卷文件路径
    /// - Parameter url: 任意分卷文件
    /// - Returns: 第一个分卷的 URL
    static func findFirstVolume(from url: URL) -> URL {
        let filename = url.lastPathComponent
        let directory = url.deletingLastPathComponent()
        
        for pattern in volumePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.regex),
                  let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) else {
                continue
            }
            
            // 通过后缀规则确定第一个文件
            let range = Range(match.range, in: filename)!
            let matchedSuffix = String(filename[range])
            let firstFileName = filename.replacingOccurrences(of: matchedSuffix, with: pattern.firstSuffix)
            
            let firstURL = directory.appendingPathComponent(firstFileName)
            if FileManager.default.fileExists(atPath: firstURL.path) {
                return firstURL
            }
        }
        
        // 无法识别则返回自身
        return url
    }
    
    /// 查找所有分卷文件，检测是否有缺失
    /// - Parameter firstVolume: 第一分卷路径
    /// - Returns: (所有找到的分卷, 缺失的分卷文件名)
    static func findAllVolumes(firstVolume: URL) -> (found: [URL], missing: [String]) {
        let directory = firstVolume.deletingLastPathComponent()
        let filename = firstVolume.lastPathComponent
        
        // 提取基本名和后缀模式
        guard let (basePattern, numberRange) = extractVolumeBase(filename: filename) else {
            return ([firstVolume], [])
        }
        
        var found: [URL] = []
        var missing: [String] = []
        var number = numberRange.lowerBound
        var consecutiveMissing = 0
        
        while consecutiveMissing < 3 { // 连续 3 个不存在则停止
            let volumeName = formatVolumeName(base: basePattern, number: number)
            let volumeURL = directory.appendingPathComponent(volumeName)
            
            if FileManager.default.fileExists(atPath: volumeURL.path) {
                found.append(volumeURL)
                consecutiveMissing = 0
            } else if !found.isEmpty {
                // 已经有找到的，后续缺失的才记录
                missing.append(volumeName)
                consecutiveMissing += 1
            } else {
                break
            }
            number += 1
        }
        
        // 去除末尾多余的 missing（超出实际分卷数的不算缺失）
        if consecutiveMissing > 0 {
            missing = Array(missing.dropLast(consecutiveMissing))
        }
        
        return (found, missing)
    }
    
    // MARK: - 私有工具方法
    
    private static func extractVolumeBase(filename: String) -> (pattern: String, range: ClosedRange<Int>)? {
        // .001 模式
        if let regex = try? NSRegularExpression(pattern: #"^(.+\.)(\d{3})$"#),
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
           let baseRange = Range(match.range(at: 1), in: filename) {
            let base = String(filename[baseRange])
            return (base + "%03d", 1...999)
        }
        
        // .part1.rar 模式
        if let regex = try? NSRegularExpression(pattern: #"^(.+\.part)\d+(\.rar)$"#),
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)),
           let baseRange = Range(match.range(at: 1), in: filename),
           let extRange = Range(match.range(at: 2), in: filename) {
            let base = String(filename[baseRange])
            let ext = String(filename[extRange])
            return (base + "%d" + ext, 1...999)
        }
        
        return nil
    }
    
    private static func formatVolumeName(base: String, number: Int) -> String {
        return String(format: base, number)
    }
}
