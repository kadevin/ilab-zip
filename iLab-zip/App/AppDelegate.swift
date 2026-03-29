import Cocoa
import os.log

private let logger = Logger(subsystem: "com.ilab.iLab-zip", category: "AppDelegate")

/// AppDelegate — 处理系统级事件
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保 7zz 有执行权限
        if let enginePath = Bundle.main.path(forResource: "7zz", ofType: nil) {
            let attrs: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
            try? FileManager.default.setAttributes(attrs, ofItemAtPath: enginePath)
            NSLog("[iLab-zip] 7zz found at: %@", enginePath)
        } else {
            NSLog("[iLab-zip] WARNING: 7zz not found in bundle Resources!")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    /// 处理打开文件（macOS 通过此方法传递文件打开请求）
    func application(_ application: NSApplication, open urls: [URL]) {
        NSLog("[iLab-zip] application open urls: %d file(s)", urls.count)
        for url in urls {
            if url.scheme == "ilabzip" {
                NSLog("[iLab-zip] Routing ilabzip URL: %@", url.absoluteString)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .finderExtensionAction, object: url)
                }
            } else {
                NSLog("[iLab-zip] Opening archive: %@", url.path)
                // 只发一次通知，而不是每个窗口实例都收到
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: .openArchive, object: url)
                }
            }
        }
    }
}

extension Notification.Name {
    static let openArchive = Notification.Name("com.ilab.iLab-zip.openArchive")
    static let extractArchive = Notification.Name("com.ilab.iLab-zip.extractArchive")
    static let compressFiles = Notification.Name("com.ilab.iLab-zip.compressFiles")
    static let finderExtensionAction = Notification.Name("com.ilab.iLab-zip.finderExtensionAction")
}
