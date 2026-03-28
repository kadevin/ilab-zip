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
        
        // 监听 Finder 扩展的操作通知
        NotificationCenter.default.addObserver(self, selector: #selector(handleExtract(_:)), name: .extractArchive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleCompress(_:)), name: .compressFiles, object: nil)
    }
    
    func openArchive(url: URL) {
        pendingArchiveURL = url
        NotificationCenter.default.post(name: .openArchive, object: url)
    }
    
    // MARK: - Finder 扩展操作处理
    
    @objc private func handleExtract(_ notification: Notification) {
        guard let engine = engine,
              let userInfo = notification.userInfo,
              let archiveURL = userInfo["archiveURL"] as? URL,
              let destinationURL = userInfo["destinationURL"] as? URL else {
            print("[iLab-zip] handleExtract: missing engine or parameters")
            return
        }
        
        print("[iLab-zip] Extracting \(archiveURL.lastPathComponent) to \(destinationURL.path)")
        
        Task {
            let stream = engine.extract(archive: archiveURL, to: destinationURL)
            var lastProgress: ArchiveProgress?
            for await progress in stream {
                lastProgress = progress
            }
            
            await MainActor.run {
                if case .failed(let err) = lastProgress?.phase {
                    self.showNotification(title: "解压失败", body: err.localizedDescription)
                } else {
                    self.showNotification(title: "解压完成", body: archiveURL.lastPathComponent)
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destinationURL.path)
                }
            }
        }
    }
    
    @objc private func handleCompress(_ notification: Notification) {
        guard let engine = engine,
              let userInfo = notification.userInfo,
              let files = userInfo["files"] as? [URL],
              let format = userInfo["format"] as? String,
              let firstFile = files.first else {
            print("[iLab-zip] handleCompress: missing engine or parameters")
            return
        }
        
        let archiveFormat: ArchiveFormat = format == "7z" ? .sevenZip : .zip
        let ext = format == "7z" ? "7z" : "zip"
        let outputName: String
        if files.count == 1 {
            outputName = firstFile.deletingPathExtension().lastPathComponent + ".\(ext)"
        } else {
            outputName = "Archive.\(ext)"
        }
        let outputURL = firstFile.deletingLastPathComponent().appendingPathComponent(outputName)
        
        print("[iLab-zip] Compressing \(files.map { $0.lastPathComponent }) to \(outputURL.path)")
        
        let options = CompressionOptions(format: archiveFormat, level: 5)
        
        Task {
            let stream = engine.compress(files: files, to: outputURL, options: options)
            var lastProgress: ArchiveProgress?
            for await progress in stream {
                lastProgress = progress
            }
            
            await MainActor.run {
                if case .failed(let err) = lastProgress?.phase {
                    self.showNotification(title: "压缩失败", body: err.localizedDescription)
                } else {
                    self.showNotification(title: "压缩完成", body: outputURL.lastPathComponent)
                    NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
                }
            }
        }
    }
    
    private func showNotification(title: String, body: String) {
        print("[iLab-zip] \(title): \(body)")
    }
}

