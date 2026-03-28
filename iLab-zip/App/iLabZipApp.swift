import SwiftUI

/// 如压 — iLab-zip 主应用入口
@main
struct iLabZipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // 主窗口 — 文件浏览器
        WindowGroup {
            ArchiveWindowView()
                .environmentObject(appState)
                .frame(minWidth: 800, minHeight: 500)
                .onOpenURL { url in
                    appState.openArchive(url: url)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        
        // 偏好设置窗口
        Settings {
            PreferencesView()
                .environmentObject(appState)
        }
    }
}

/// 全局应用状态
final class AppState: ObservableObject {
    @Published var engine: ArchiveEngine?
    @Published var pendingArchiveURL: URL?
    
    init() {
        // 尝试从 bundle 加载引擎
        do {
            engine = try ArchiveEngine()
            print("[iLab-zip] ArchiveEngine initialized from bundle")
        } catch {
            print("[iLab-zip] Bundle engine failed: \(error)")
        }
        
        // 如果 Bundle 中找不到，尝试从 app 同级目录查找
        if engine == nil {
            let appPath = Bundle.main.bundlePath
            let appDir = (appPath as NSString).deletingLastPathComponent
            let fallbackPath = (appDir as NSString).appendingPathComponent("7zz")
            if FileManager.default.fileExists(atPath: fallbackPath) {
                engine = ArchiveEngine(enginePath: fallbackPath)
                print("[iLab-zip] ArchiveEngine initialized from fallback: \(fallbackPath)")
            }
        }
        
        if engine == nil {
            print("[iLab-zip] WARNING: No 7zz engine found!")
        }
    }
    
    func openArchive(url: URL) {
        pendingArchiveURL = url
        // 同时通过通知通知已有的 ArchiveWindowView
        NotificationCenter.default.post(name: .openArchive, object: url)
    }
}
