import Cocoa
import FinderSync

class FinderSyncExtension: FIFinderSync {
    
    override init() {
        super.init()
        // 监控用户主目录
        let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        FIFinderSyncController.default().directoryURLs = [homeDir]
    }
    
    // MARK: - 右键菜单
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "iLab-zip")
        
        switch menuKind {
        case .contextualMenuForItems:
            // 根据选中文件类型决定显示哪些菜单项
            let items = FIFinderSyncController.default().selectedItemURLs() ?? []
            let hasArchives = items.contains { isArchiveFile($0) }
            
            if hasArchives {
                menu.addItem(withTitle: NSLocalizedString("toolbar.extract", comment: "解压到当前文件夹"),
                           action: #selector(extractHere(_:)),
                           keyEquivalent: "")
                menu.addItem(withTitle: NSLocalizedString("toolbar.extractTo", comment: "解压到指定位置..."),
                           action: #selector(extractTo(_:)),
                           keyEquivalent: "")
            }
            
            menu.addItem(NSMenuItem.separator())
            
            menu.addItem(withTitle: "压缩到 7z",
                       action: #selector(compressTo7z(_:)),
                       keyEquivalent: "")
            menu.addItem(withTitle: "压缩到 ZIP",
                       action: #selector(compressToZip(_:)),
                       keyEquivalent: "")
            
        default:
            break
        }
        
        return menu
    }
    
    // MARK: - 菜单动作
    
    @objc func extractHere(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        for item in items where isArchiveFile(item) {
            sendXPCCommand(.extractHere, archivePath: item.path)
        }
    }
    
    @objc func extractTo(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            for item in items where self.isArchiveFile(item) {
                self.sendXPCCommand(.extractTo, archivePath: item.path, destinationPath: dest.path)
            }
        }
    }
    
    @objc func compressTo7z(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(), let first = items.first else { return }
        let outputName = first.deletingPathExtension().lastPathComponent + ".7z"
        let outputPath = first.deletingLastPathComponent().appendingPathComponent(outputName).path
        sendXPCCommand(.compressTo7z, files: items.map { $0.path }, outputPath: outputPath)
    }
    
    @objc func compressToZip(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(), let first = items.first else { return }
        let outputName = first.deletingPathExtension().lastPathComponent + ".zip"
        let outputPath = first.deletingLastPathComponent().appendingPathComponent(outputName).path
        sendXPCCommand(.compressToZip, files: items.map { $0.path }, outputPath: outputPath)
    }
    
    // MARK: - XPC 通信
    
    enum XPCCommand {
        case extractHere
        case extractTo
        case compressTo7z
        case compressToZip
    }
    
    private func sendXPCCommand(_ command: XPCCommand, archivePath: String? = nil, destinationPath: String? = nil, files: [String]? = nil, outputPath: String? = nil) {
        let serviceName = "com.ilab.iLab-zip.XPCService"
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: ArchiveXPCProtocol.self)
        connection.resume()
        
        guard let proxy = connection.remoteObjectProxy as? ArchiveXPCProtocol else {
            connection.invalidate()
            return
        }
        
        switch command {
        case .extractHere:
            if let path = archivePath {
                proxy.extractHere(archivePath: path) { success, error in
                    if !success {
                        NSLog("iLab-zip: Extract failed: \(error ?? "unknown")")
                    }
                    connection.invalidate()
                }
            }
        case .extractTo:
            if let path = archivePath, let dest = destinationPath {
                proxy.extractTo(archivePath: path, destinationPath: dest) { success, error in
                    if !success {
                        NSLog("iLab-zip: Extract failed: \(error ?? "unknown")")
                    }
                    connection.invalidate()
                }
            }
        case .compressTo7z:
            if let files = files, let output = outputPath {
                proxy.compressTo7z(files: files, outputPath: output) { success, error in
                    if !success {
                        NSLog("iLab-zip: Compress failed: \(error ?? "unknown")")
                    }
                    connection.invalidate()
                }
            }
        case .compressToZip:
            if let files = files, let output = outputPath {
                proxy.compressToZip(files: files, outputPath: output) { success, error in
                    if !success {
                        NSLog("iLab-zip: Compress failed: \(error ?? "unknown")")
                    }
                    connection.invalidate()
                }
            }
        }
    }
    
    // MARK: - 工具
    
    private func isArchiveFile(_ url: URL) -> Bool {
        let supportedExtensions = ["7z", "zip", "rar", "tar", "gz", "bz2", "xz", "iso", "dmg", "cab", "arj", "lzh", "wim"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
