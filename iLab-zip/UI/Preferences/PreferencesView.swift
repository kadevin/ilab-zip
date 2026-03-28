import SwiftUI

/// 偏好设置 — 主视图
struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label(NSLocalizedString("preferences.general", comment: "通用"), systemImage: "gear")
                }
            
            PasswordVaultView()
                .tabItem {
                    Label(NSLocalizedString("preferences.vault", comment: "密码库"), systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 400)
    }
}
