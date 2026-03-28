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
            // 列出 Resources 目录内容以便调试
            if let resourcePath = Bundle.main.resourcePath {
                let contents = (try? FileManager.default.contentsOfDirectory(atPath: resourcePath)) ?? []
                print("[iLab-zip] Resources contents: \(contents)")
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        print("[iLab-zip] AppDelegate openFile: \(filename)")
        // 延迟一小段时间确保 UI 已就绪
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
}

extension Notification.Name {
    static let openArchive = Notification.Name("com.ilab.iLab-zip.openArchive")
}
