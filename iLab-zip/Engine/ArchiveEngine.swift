import Foundation

/// 压缩引擎 — 封装 7zz 调用
final class ArchiveEngine: ObservableObject {
    
    /// 7zz 二进制路径
    private let enginePath: String
    
    /// 当前运行的进程（用于取消）
    private var runningProcess: Process?
    
    init() throws {
        guard let path = Bundle.main.path(forResource: "7zz", ofType: nil) else {
            throw ArchiveError.engineNotFound
        }
        self.enginePath = path
    }
    
    /// 用于测试：手动指定 7zz 路径
    init(enginePath: String) {
        self.enginePath = enginePath
    }
    
    // MARK: - 列出压缩包内容
    
    /// 列出压缩包所有条目（使用 7zz l -slt）
    nonisolated func listContents(of archive: URL, password: String? = nil) async throws -> [ArchiveEntry] {
        var args = ["l", "-slt", archive.path]
        if let password = password {
            args.append("-p\(password)")
        }
        
        let output = try await runCommand(args: args)
        return parseListOutput(output)
    }
    
    // MARK: - 解压全部
    
    /// 解压全部文件到目标目录
    nonisolated func extract(archive: URL, to destination: URL, password: String? = nil) -> AsyncStream<ArchiveProgress> {
        var args = ["x", archive.path, "-o\(destination.path)", "-y"]
        if let password = password {
            args.append("-p\(password)")
        }
        return runWithProgress(args: args)
    }
    
    // MARK: - 解压选中文件
    
    /// 解压指定文件到目标目录
    nonisolated func extractSelected(archive: URL, entries: [String], to destination: URL, password: String? = nil) -> AsyncStream<ArchiveProgress> {
        var args = ["x", archive.path]
        args.append(contentsOf: entries)
        args.append("-o\(destination.path)")
        args.append("-y")
        if let password = password {
            args.append("-p\(password)")
        }
        return runWithProgress(args: args)
    }
    
    // MARK: - 压缩
    
    /// 创建压缩包
    nonisolated func compress(files: [URL], to archive: URL, options: CompressionOptions) -> AsyncStream<ArchiveProgress> {
        var args = ["a"]
        
        // 格式
        args.append("-t\(options.format.rawValue)")
        
        // 压缩等级
        args.append("-mx=\(options.level)")
        
        // 密码
        if let password = options.password, !password.isEmpty {
            args.append("-p\(password)")
            if options.encryptFilenames && options.format == .sevenZip {
                args.append("-mhe=on")
            }
        }
        
        // 分卷
        if let volumeMB = options.volumeSize.megabytes {
            args.append("-v\(volumeMB)m")
        }
        
        // 输出文件
        args.append(archive.path)
        
        // 输入文件列表
        args.append(contentsOf: files.map { $0.path })
        
        return runWithProgress(args: args)
    }
    
    // MARK: - 测试完整性
    
    /// 测试压缩包完整性（用于检测是否加密及密码是否正确）
    nonisolated func testIntegrity(of archive: URL, password: String? = nil) async throws -> Bool {
        var args = ["t", archive.path]
        if let password = password {
            args.append("-p\(password)")
        }
        
        do {
            _ = try await runCommand(args: args)
            return true
        } catch let error as ArchiveError {
            switch error {
            case .wrongPassword:
                return false
            default:
                throw error
            }
        }
    }
    
    // MARK: - 检测是否加密
    
    /// 通过尝试不带密码的 test 命令检测压缩包是否加密
    nonisolated func isEncrypted(archive: URL) async -> Bool {
        do {
            _ = try await testIntegrity(of: archive, password: nil)
            return false
        } catch {
            if case ArchiveError.wrongPassword = error {
                return true
            }
            return false
        }
    }
    
    // MARK: - 取消
    
    func cancel() {
        runningProcess?.terminate()
        runningProcess = nil
    }
    
    // MARK: - 私有方法
    
    /// 执行 7zz 命令并返回完整输出
    private nonisolated func runCommand(args: [String]) async throws -> String {
        print("[iLab-zip] runCommand: \(enginePath) \(args.joined(separator: " "))")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [enginePath] in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: enginePath)
                process.arguments = args
                
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    
                    print("[iLab-zip] Process exit code: \(process.terminationStatus), stdout length: \(stdout.count)")
                    
                    guard process.terminationStatus == 0 else {
                        continuation.resume(throwing: ArchiveError.from(exitCode: process.terminationStatus, stderr: stderr))
                        return
                    }
                    
                    continuation.resume(returning: stdout)
                } catch {
                    print("[iLab-zip] Process launch error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 执行 7zz 命令并实时推送进度
    private nonisolated func runWithProgress(args: [String]) -> AsyncStream<ArchiveProgress> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: enginePath)
            process.arguments = args + ["-bsp1"] // 启用进度输出到 stdout
            
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            
            // 发送准备阶段
            continuation.yield(ArchiveProgress(
                phase: .preparing,
                percentage: 0,
                currentFile: nil,
                bytesProcessed: 0,
                totalBytes: 0,
                speed: nil
            ))
            
            // 实时读取进度输出 — 使用引用类型避免并发捕获警告
            final class LineBuffer: @unchecked Sendable {
                var accumulated = ""
            }
            let buffer = LineBuffer()
            
            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                
                guard let text = String(data: data, encoding: .utf8) else { return }
                buffer.accumulated += text
                
                // 按行解析
                while let newlineRange = buffer.accumulated.range(of: "\r") ?? buffer.accumulated.range(of: "\n") {
                    let line = String(buffer.accumulated[buffer.accumulated.startIndex..<newlineRange.lowerBound])
                    buffer.accumulated = String(buffer.accumulated[newlineRange.upperBound...])
                    
                    if let progress = Self.parseProgressLine(line) {
                        continuation.yield(progress)
                    }
                }
            }
            
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                
                if proc.terminationStatus == 0 {
                    continuation.yield(ArchiveProgress(
                        phase: .completed,
                        percentage: 100,
                        currentFile: nil,
                        bytesProcessed: 0,
                        totalBytes: 0,
                        speed: nil
                    ))
                } else {
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                    let error = ArchiveError.from(exitCode: proc.terminationStatus, stderr: stderr)
                    continuation.yield(ArchiveProgress(
                        phase: .failed(error),
                        percentage: 0,
                        currentFile: nil,
                        bytesProcessed: 0,
                        totalBytes: 0,
                        speed: nil
                    ))
                }
                
                continuation.finish()
            }
            
            do {
                try process.run()
                // Store for cancellation - dispatch to main actor
                Task { @MainActor [weak self] in
                    self?.runningProcess = process
                }
            } catch {
                continuation.yield(ArchiveProgress(
                    phase: .failed(error),
                    percentage: 0,
                    currentFile: nil,
                    bytesProcessed: 0,
                    totalBytes: 0,
                    speed: nil
                ))
                continuation.finish()
            }
            
            continuation.onTermination = { @Sendable _ in
                if process.isRunning {
                    process.terminate()
                }
            }
        }
    }
    
    // MARK: - 输出解析
    
    /// 解析 7zz l -slt 输出为 ArchiveEntry 数组
    private func parseListOutput(_ output: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        let blocks = output.components(separatedBy: "\n\n")
        
        for block in blocks {
            var path: String?
            var size: UInt64 = 0
            var compressedSize: UInt64 = 0
            var modifiedDate: Date?
            var isDirectory = false
            var isEncrypted = false
            var crc: String?
            
            let lines = block.components(separatedBy: "\n")
            for line in lines {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2 else { continue }
                let key = parts[0]
                let value = parts[1]
                
                switch key {
                case "Path":
                    path = value
                case "Size":
                    size = UInt64(value) ?? 0
                case "Packed Size":
                    compressedSize = UInt64(value) ?? 0
                case "Modified":
                    modifiedDate = Self.dateFormatter.date(from: value)
                case "Folder":
                    isDirectory = value == "+"
                case "Encrypted":
                    isEncrypted = value == "+"
                case "CRC":
                    crc = value
                default:
                    break
                }
            }
            
            if let path = path {
                let name = (path as NSString).lastPathComponent
                entries.append(ArchiveEntry(
                    path: path,
                    name: name,
                    size: size,
                    compressedSize: compressedSize,
                    modifiedDate: modifiedDate,
                    isDirectory: isDirectory,
                    isEncrypted: isEncrypted,
                    crc: crc
                ))
            }
        }
        
        return entries
    }
    
    /// 解析进度行（例如 "  45% 12 - src/main.swift"）
    nonisolated static func parseProgressLine(_ line: String) -> ArchiveProgress? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // 匹配百分比模式：数字%
        let pattern = #"(\d+)%\s*(?:\d+\s*-\s*(.*))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return nil
        }
        
        guard let percentRange = Range(match.range(at: 1), in: trimmed),
              let percent = Double(trimmed[percentRange]) else {
            return nil
        }
        
        var currentFile: String?
        if match.numberOfRanges > 2, let fileRange = Range(match.range(at: 2), in: trimmed) {
            let file = String(trimmed[fileRange]).trimmingCharacters(in: .whitespaces)
            if !file.isEmpty {
                currentFile = file
            }
        }
        
        return ArchiveProgress(
            phase: .processing,
            percentage: percent,
            currentFile: currentFile,
            bytesProcessed: 0,
            totalBytes: 0,
            speed: nil
        )
    }
    
    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return fmt
    }()
}
