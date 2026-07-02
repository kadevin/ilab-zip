import AppKit
import SwiftUI

/// 通用设置 — 语言切换
struct GeneralSettingsView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "system"
    @State private var monitoredDirectories: [URL] = FinderSyncMonitoredDirectoryStore().directoryURLs()
    @State private var directoryError: String?
    private let monitoredDirectoryStore = FinderSyncMonitoredDirectoryStore()
    
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

            Section(NSLocalizedString("settings.finderDirectories", comment: "Finder 右键目录")) {
                if monitoredDirectories.isEmpty {
                    Text(NSLocalizedString("settings.finderDirectories.empty", comment: "未添加自定义目录"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monitoredDirectories, id: \.path) { url in
                        HStack {
                            Text(url.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                removeMonitoredDirectory(url)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                Button {
                    addMonitoredDirectory()
                } label: {
                    Label(NSLocalizedString("settings.finderDirectories.add", comment: "添加目录"), systemImage: "plus")
                }

                if let directoryError {
                    Text(directoryError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func addMonitoredDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = NSLocalizedString("button.add", comment: "添加")

        guard panel.runModal() == .OK else { return }

        monitoredDirectories.append(contentsOf: panel.urls)
        saveMonitoredDirectories()
    }

    private func removeMonitoredDirectory(_ url: URL) {
        monitoredDirectories.removeAll { $0.standardizedFileURL.path == url.standardizedFileURL.path }
        saveMonitoredDirectories()
    }

    private func saveMonitoredDirectories() {
        do {
            try monitoredDirectoryStore.save(monitoredDirectories)
            monitoredDirectories = monitoredDirectoryStore.directoryURLs()
            directoryError = nil
        } catch {
            directoryError = error.localizedDescription
        }
    }
}
