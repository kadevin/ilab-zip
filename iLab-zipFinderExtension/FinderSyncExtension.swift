import Cocoa
import FinderSync

class FinderSyncExtension: FIFinderSync {
    
    override init() {
        super.init()
        NSLog("[iLab-zip FinderSync] Extension initializing...")
        // 监控所有目录（根目录），确保 Finder 中任何位置右键都能触发
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        NSLog("[iLab-zip FinderSync] Monitoring directory: /")
    }
    
    // MARK: - 右键菜单
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        NSLog("[iLab-zip FinderSync] menu(for:) called, menuKind=\(menuKind.rawValue)")
        let menu = NSMenu(title: "如压")
        
        switch menuKind {
        case .contextualMenuForItems:
            let items = FIFinderSyncController.default().selectedItemURLs() ?? []
            NSLog("[iLab-zip FinderSync] Selected items: \(items.map { $0.lastPathComponent })")
            let hasArchives = items.contains { isArchiveFile($0) }
            
            if hasArchives {
                let extractItem = NSMenuItem(title: "解压到当前文件夹", action: #selector(extractHere(_:)), keyEquivalent: "")
                extractItem.target = self
                menu.addItem(extractItem)
                
                let extractToItem = NSMenuItem(title: "解压到指定位置...", action: #selector(extractTo(_:)), keyEquivalent: "")
                extractToItem.target = self
                menu.addItem(extractToItem)
                
                menu.addItem(NSMenuItem.separator())
            }
            
            let compress7zItem = NSMenuItem(title: "压缩到 7z", action: #selector(compressTo7z(_:)), keyEquivalent: "")
            compress7zItem.target = self
            menu.addItem(compress7zItem)
            
            let compressZipItem = NSMenuItem(title: "压缩到 ZIP", action: #selector(compressToZip(_:)), keyEquivalent: "")
            compressZipItem.target = self
            menu.addItem(compressZipItem)
            
        default:
            break
        }
        
        NSLog("[iLab-zip FinderSync] Returning menu with \(menu.items.count) items")
        return menu
    }
    
    // MARK: - 菜单动作
    
    @objc func extractHere(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let archiveFiles = items.filter { isArchiveFile($0) }
        NSLog("[iLab-zip FinderSync] extractHere: \(archiveFiles.map { $0.lastPathComponent })")
        for item in archiveFiles {
            openMainApp(action: "extract", files: [item.path])
        }
    }
    
    @objc func extractTo(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        let archiveFiles = items.filter { isArchiveFile($0) }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "选择目标文件夹"
        
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            NSLog("[iLab-zip FinderSync] extractTo: \(dest.path)")
            for item in archiveFiles {
                self.openMainApp(action: "extractto", files: [item.path], dest: dest.path)
            }
        }
    }
    
    @objc func compressTo7z(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        NSLog("[iLab-zip FinderSync] compress7z: \(items.map { $0.lastPathComponent })")
        openMainApp(action: "compress7z", files: items.map { $0.path })
    }
    
    @objc func compressToZip(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs() else { return }
        NSLog("[iLab-zip FinderSync] compressZip: \(items.map { $0.lastPathComponent })")
        openMainApp(action: "compresszip", files: items.map { $0.path })
    }
    
    // MARK: - 通过 URL Scheme 调用主应用
    
    private func openMainApp(action: String, files: [String], dest: String? = nil) {
        var components = URLComponents()
        components.scheme = "ilabzip"
        components.host = action
        
        var queryItems = files.map { URLQueryItem(name: "file", value: $0) }
        if let dest = dest {
            queryItems.append(URLQueryItem(name: "dest", value: dest))
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            NSLog("[iLab-zip FinderSync] Failed to construct URL")
            return
        }
        
        NSLog("[iLab-zip FinderSync] Opening URL: \(url.absoluteString)")
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - 工具
    
    private func isArchiveFile(_ url: URL) -> Bool {
        let supportedExtensions = ["7z", "zip", "rar", "tar", "gz", "bz2", "xz", "iso", "dmg", "cab", "arj", "lzh", "wim"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
}

