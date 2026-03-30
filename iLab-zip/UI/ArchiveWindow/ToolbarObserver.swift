import Cocoa

/// 监听 NSToolbar 显示模式变化并持久化到 UserDefaults
/// 因为 NSToolbar.displayMode 的 KVO 不可靠，使用定时轮询方式
final class ToolbarObserver: NSObject {
    static let shared = ToolbarObserver()
    
    private weak var toolbar: NSToolbar?
    private var timer: Timer?
    private var lastMode: NSToolbar.DisplayMode = .default
    
    func observe(toolbar: NSToolbar) {
        self.toolbar = toolbar
        self.lastMode = toolbar.displayMode
        
        // 停止旧的定时器
        timer?.invalidate()
        
        // 每 2 秒检查一次 displayMode 是否变化
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self, let toolbar = self.toolbar else { return }
            if toolbar.displayMode != self.lastMode {
                self.lastMode = toolbar.displayMode
                let mode = Int(toolbar.displayMode.rawValue)
                UserDefaults.standard.set(mode, forKey: "toolbarDisplayMode")
                NSLog("[iLab-zip] Toolbar displayMode saved: %d", mode)
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
