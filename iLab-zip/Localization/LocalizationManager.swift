import Foundation

/// 语言管理器
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "system"
        self.currentLanguage = saved
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localeDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    }
    
    /// 设置语言
    func setLanguage(_ language: String) {
        currentLanguage = language
        UserDefaults.standard.set(language, forKey: "selectedLanguage")
        
        if language == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
        }
        
        // 通知 UI 刷新
        objectWillChange.send()
    }
    
    @objc private func localeDidChange() {
        if currentLanguage == "system" {
            objectWillChange.send()
        }
    }
}
