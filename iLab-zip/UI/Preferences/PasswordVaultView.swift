import SwiftUI

/// 密码库管理视图
struct PasswordVaultView: View {
    @State private var passwords: [PasswordEntry] = []
    @State private var showAddPassword: Bool = false
    @State private var newPassword: String = ""
    @State private var newLabel: String = ""
    @State private var selectedPasswordId: Int64?
    
    var body: some View {
        VStack(spacing: 0) {
            // 密码列表
            List(selection: $selectedPasswordId) {
                ForEach(passwords) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.label ?? NSLocalizedString("vault.noLabel", comment: "无备注"))
                                .font(.body)
                            Text(maskedPassword(entry))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let usedAt = entry.usedAt {
                            Text(usedAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    .tag(entry.id)
                }
                .onDelete(perform: deletePasswords)
            }
            
            Divider()
            
            // 底部工具栏
            HStack {
                Button(action: { showAddPassword = true }) {
                    Image(systemName: "plus")
                }
                
                Button(action: deleteSelected) {
                    Image(systemName: "minus")
                }
                .disabled(selectedPasswordId == nil)
                
                Spacer()
                
                Text(String(format: NSLocalizedString("vault.count", comment: "共 %d 个密码"), passwords.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .onAppear { loadPasswords() }
        .sheet(isPresented: $showAddPassword) {
            VStack(spacing: 16) {
                Text(NSLocalizedString("vault.addPassword", comment: "添加密码"))
                    .font(.headline)
                
                SecureField(NSLocalizedString("vault.password", comment: "密码"), text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                TextField(NSLocalizedString("vault.label", comment: "备注（可选）"), text: $newLabel)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 250)
                
                HStack {
                    Button(NSLocalizedString("button.cancel", comment: "取消")) {
                        showAddPassword = false
                        newPassword = ""
                        newLabel = ""
                    }
                    
                    Button(NSLocalizedString("button.add", comment: "添加")) {
                        addPassword()
                    }
                    .disabled(newPassword.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 320)
        }
    }
    
    private func loadPasswords() {
        passwords = (try? PasswordVault.shared.allPasswords()) ?? []
    }
    
    private func addPassword() {
        _ = try? PasswordVault.shared.addPassword(label: newLabel.isEmpty ? nil : newLabel, plaintext: newPassword)
        newPassword = ""
        newLabel = ""
        showAddPassword = false
        loadPasswords()
    }
    
    private func deletePasswords(at offsets: IndexSet) {
        for index in offsets {
            if let id = passwords[index].id {
                try? PasswordVault.shared.removePassword(id: id)
            }
        }
        loadPasswords()
    }
    
    private func deleteSelected() {
        if let id = selectedPasswordId {
            try? PasswordVault.shared.removePassword(id: id)
            selectedPasswordId = nil
            loadPasswords()
        }
    }
    
    private func maskedPassword(_ entry: PasswordEntry) -> String {
        guard let plaintext = entry.plaintext else { return "••••••••" }
        if plaintext.count <= 2 {
            return String(repeating: "•", count: plaintext.count)
        }
        let first = plaintext.prefix(1)
        let last = plaintext.suffix(1)
        let middle = String(repeating: "•", count: min(plaintext.count - 2, 6))
        return "\(first)\(middle)\(last)"
    }
}
