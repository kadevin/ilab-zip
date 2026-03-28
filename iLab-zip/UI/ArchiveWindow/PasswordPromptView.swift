import SwiftUI

/// 密码输入弹窗
struct PasswordPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var password: String = ""
    @State private var saveToVault: Bool = true
    @State private var label: String = ""
    
    var onSubmit: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text(NSLocalizedString("password.title", comment: "输入密码"))
                    .font(.headline)
            }
            
            Text(NSLocalizedString("password.description", comment: "该压缩包已加密，请输入密码以解压。"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // 密码输入
            SecureField(NSLocalizedString("password.placeholder", comment: "密码"), text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit {
                    submit()
                }
            
            // 保存选项
            VStack(alignment: .leading, spacing: 8) {
                Toggle(NSLocalizedString("password.saveToVault", comment: "保存到密码库"), isOn: $saveToVault)
                
                if saveToVault {
                    TextField(NSLocalizedString("password.label", comment: "备注（可选）"), text: $label)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }
            }
            
            // 按钮
            HStack(spacing: 12) {
                Button(NSLocalizedString("button.cancel", comment: "取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(NSLocalizedString("button.ok", comment: "确定")) {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 400)
    }
    
    private func submit() {
        guard !password.isEmpty else { return }
        
        if saveToVault {
            _ = try? PasswordVault.shared.addPassword(label: label.isEmpty ? nil : label, plaintext: password)
        }
        
        onSubmit(password)
        dismiss()
    }
}
