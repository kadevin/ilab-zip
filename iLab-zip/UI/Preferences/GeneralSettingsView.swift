import SwiftUI

/// 通用设置 — 语言切换
struct GeneralSettingsView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "system"
    
    var body: some View {
        Form {
            Section(NSLocalizedString("settings.language", comment: "语言")) {
                Picker(NSLocalizedString("settings.language", comment: "语言"), selection: $selectedLanguage) {
                    Text(NSLocalizedString("settings.language.system", comment: "跟随系统")).tag("system")
                    Text("中文").tag("zh-Hans")
                    Text("English").tag("en")
                }
                .pickerStyle(.radioGroup)
                .onChange(of: selectedLanguage) { newValue in
                    LocalizationManager.shared.setLanguage(newValue)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
