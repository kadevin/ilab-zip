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
                    if url.scheme == "ilabzip" {
                        appState.handleFinderExtensionURL(url)
                    } else {
                        // 文件打开 — 通过通知分发给 ArchiveWindowView
                        NSLog("[iLab-zip] onOpenURL file: %@", url.path)
                        NotificationCenter.default.post(name: .openArchive, object: url)
                    }
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
            NSLog("[iLab-zip] ArchiveEngine initialized from bundle")
        } catch {
            NSLog("[iLab-zip] Bundle engine failed: %@", error.localizedDescription)
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
    
    /// 处理来自 Finder 扩展的 URL 命令
    func handleFinderExtensionURL(_ url: URL) {
        print("[iLab-zip] Received Finder extension URL: \(url.absoluteString)")
        
        let action = url.host ?? ""
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let files = params?.queryItems?.filter { $0.name == "file" }.compactMap {
            $0.value?.removingPercentEncoding
        } ?? []
        let dest = params?.queryItems?.first(where: { $0.name == "dest" })?.value?.removingPercentEncoding
        
        print("[iLab-zip] Action: \(action), Files: \(files), Dest: \(dest ?? "nil")")
        
        switch action {
        case "extract":
            for file in files {
                let fileURL = URL(fileURLWithPath: file)
                let destURL = URL(fileURLWithPath: dest ?? fileURL.deletingLastPathComponent().path)
                NotificationCenter.default.post(name: .extractArchive, object: nil,
                                               userInfo: ["archiveURL": fileURL, "destinationURL": destURL])
            }
        case "extractto":
            for file in files {
                let fileURL = URL(fileURLWithPath: file)
                if let destPath = dest {
                    let destURL = URL(fileURLWithPath: destPath)
                    NotificationCenter.default.post(name: .extractArchive, object: nil,
                                                   userInfo: ["archiveURL": fileURL, "destinationURL": destURL])
                }
            }
        case "compress7z":
            let fileURLs = files.map { URL(fileURLWithPath: $0) }
            NotificationCenter.default.post(name: .compressFiles, object: nil,
                                           userInfo: ["files": fileURLs, "format": "7z"])
        case "compresszip":
            let fileURLs = files.map { URL(fileURLWithPath: $0) }
            NotificationCenter.default.post(name: .compressFiles, object: nil,
                                           userInfo: ["files": fileURLs, "format": "zip"])
        default:
            print("[iLab-zip] Unknown action: \(action)")
        }
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

