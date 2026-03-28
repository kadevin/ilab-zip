import Cocoa

/// AppDelegate — 处理系统级事件
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保 7zz 有执行权限
        if let enginePath = Bundle.main.path(forResource: "7zz", ofType: nil) {
            let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
            try? FileManager.default.setAttributes(attrs, ofItemAtPath: enginePath)
            print("[iLab-zip] 7zz found at: \(enginePath)")
        } else {
            print("[iLab-zip] WARNING: 7zz not found in bundle Resources!")
            if let resourcePath = Bundle.main.resourcePath {
                let contents = (try? FileManager.default.contentsOfDirectory(atPath: resourcePath)) ?? []
                print("[iLab-zip] Resources contents: \(contents)")
            }
        }
        
        // 注册 URL scheme 处理
        let em = NSAppleEventManager.shared()
        em.setEventHandler(self,
                          andSelector: #selector(handleURLEvent(_:withReply:)),
                          forEventClass: AEEventClass(kInternetEventClass),
                          andEventID: AEEventID(kAEGetURL))
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        print("[iLab-zip] AppDelegate openFile: \(filename)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NotificationCenter.default.post(name: .openArchive, object: url)
        }
        return true
    }
    
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            print("[iLab-zip] AppDelegate openFiles: \(filename)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(name: .openArchive, object: url)
            }
        }
    }
    
    // MARK: - URL Scheme Handler
    
    /// 处理来自 Finder 扩展的 URL 调用
    /// 格式: ilabzip://action?files=path1&files=path2&dest=destPath
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            print("[iLab-zip] Invalid URL event")
            return
        }
        
        print("[iLab-zip] Received URL: \(urlString)")
        
        let action = url.host ?? ""
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let files = params?.queryItems?.filter { $0.name == "file" }.compactMap {
            $0.value?.removingPercentEncoding
        } ?? []
        let dest = params?.queryItems?.first(where: { $0.name == "dest" })?.value?.removingPercentEncoding
        
        print("[iLab-zip] Action: \(action), Files: \(files), Dest: \(dest ?? "nil")")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch action {
            case "extract":
                // 解压到当前文件夹
                for file in files {
                    let fileURL = URL(fileURLWithPath: file)
                    let destURL = URL(fileURLWithPath: dest ?? fileURL.deletingLastPathComponent().path)
                    NotificationCenter.default.post(name: .extractArchive,
                                                   object: nil,
                                                   userInfo: ["archiveURL": fileURL, "destinationURL": destURL])
                }
            case "extractto":
                // 解压到指定位置（由 Finder 扩展通过 NSOpenPanel 选择）
                for file in files {
                    let fileURL = URL(fileURLWithPath: file)
                    if let destPath = dest {
                        let destURL = URL(fileURLWithPath: destPath)
                        NotificationCenter.default.post(name: .extractArchive,
                                                       object: nil,
                                                       userInfo: ["archiveURL": fileURL, "destinationURL": destURL])
                    }
                }
            case "compress7z":
                let fileURLs = files.map { URL(fileURLWithPath: $0) }
                NotificationCenter.default.post(name: .compressFiles,
                                               object: nil,
                                               userInfo: ["files": fileURLs, "format": "7z"])
            case "compresszip":
                let fileURLs = files.map { URL(fileURLWithPath: $0) }
                NotificationCenter.default.post(name: .compressFiles,
                                               object: nil,
                                               userInfo: ["files": fileURLs, "format": "zip"])
            default:
                print("[iLab-zip] Unknown action: \(action)")
            }
        }
    }
}

extension Notification.Name {
    static let openArchive = Notification.Name("com.ilab.iLab-zip.openArchive")
    static let extractArchive = Notification.Name("com.ilab.iLab-zip.extractArchive")
    static let compressFiles = Notification.Name("com.ilab.iLab-zip.compressFiles")
}

