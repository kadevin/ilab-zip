import SwiftUI

/// 压缩配置对话框
struct CompressionSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    /// 从 Finder 预设的文件列表（nil 时弹出文件选择器）
    var presetFiles: [URL]? = nil
    /// 是否默认启用分卷
    var defaultSplit: Bool = false
    
    @State private var selectedFiles: [URL] = []
    @State private var outputName: String = "archive"
    @State private var format: ArchiveFormat = .sevenZip
    @State private var compressionLevel: Double = 5
    @State private var password: String = ""
    @State private var encryptFilenames: Bool = false
    @State private var volumeSize: CompressionOptions.VolumeSize = .none
    @State private var customVolumeMB: String = ""
    @State private var isCompressing: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(defaultSplit
                 ? NSLocalizedString("compress.splitTitle", comment: "创建分卷压缩包")
                 : NSLocalizedString("compress.title", comment: "创建压缩包"))
                .font(.headline)
            
            // 已选文件摘要
            if !selectedFiles.isEmpty {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                    Text(String(format: "已选择 %d 个文件/文件夹", selectedFiles.count))
                        .foregroundColor(.secondary)
                    Spacer()
                    if presetFiles == nil {
                        Button("重新选择") {
                            chooseFiles()
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Form {
                // 输出文件名
                TextField(NSLocalizedString("compress.outputName", comment: "文件名"), text: $outputName)
                
                // 格式选择
                Picker(NSLocalizedString("compress.format", comment: "格式"), selection: $format) {
                    ForEach(ArchiveFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                
                // 压缩等级
                HStack {
                    Text(NSLocalizedString("compress.level", comment: "压缩等级"))
                    Slider(value: $compressionLevel, in: 1...9, step: 1) {
                        Text(NSLocalizedString("compress.level", comment: "压缩等级"))
                    }
                    Text("\(Int(compressionLevel))")
                        .monospacedDigit()
                        .frame(width: 20)
                }
                
                // 密码
                Section(NSLocalizedString("compress.encryption", comment: "加密")) {
                    SecureField(NSLocalizedString("compress.password", comment: "密码（留空则不加密）"), text: $password)
                    
                    if !password.isEmpty && format == .sevenZip {
                        Toggle(NSLocalizedString("compress.encryptFilenames", comment: "加密文件名"), isOn: $encryptFilenames)
                    }
                }
                
                // 分卷大小
                Section(NSLocalizedString("compress.volume", comment: "分卷")) {
                    Picker(NSLocalizedString("compress.volumeSize", comment: "分卷大小"), selection: $volumeSize) {
                        ForEach(Array(CompressionOptions.VolumeSize.presets.enumerated()), id: \.offset) { _, preset in
                            Text(preset.0).tag(preset.1)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            // 按钮
            HStack(spacing: 12) {
                Button(NSLocalizedString("button.cancel", comment: "取消")) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(NSLocalizedString("compress.start", comment: "开始压缩")) {
                    startCompression()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedFiles.isEmpty || outputName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 450, height: 500)
        .onAppear {
            if let preset = presetFiles, !preset.isEmpty {
                // 使用预设文件，不弹文件选择器
                selectedFiles = preset
                if let first = preset.first {
                    outputName = first.deletingPathExtension().lastPathComponent
                }
            } else {
                chooseFiles()
            }
            
            // 默认分卷：预设 100MB
            if defaultSplit {
                volumeSize = .preset(megabytes: 100)
            }
        }
    }
    
    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = NSLocalizedString("button.choose", comment: "选择")
        
        panel.begin { response in
            if response == .OK {
                selectedFiles = panel.urls
                if let first = panel.urls.first {
                    outputName = first.deletingPathExtension().lastPathComponent
                }
            } else if presetFiles == nil {
                // 用户取消了文件选择，关闭对话框
                dismiss()
            }
        }
    }
    
    private func startCompression() {
        guard let engine = appState.engine else { return }
        
        let ext = format.rawValue
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(outputName).\(ext)"
        panel.allowedContentTypes = [.data]
        
        panel.begin { response in
            guard response == .OK, let outputURL = panel.url else { return }
            
            let options = CompressionOptions(
                format: format,
                level: Int(compressionLevel),
                password: password.isEmpty ? nil : password,
                encryptFilenames: encryptFilenames,
                volumeSize: volumeSize
            )
            
            dismiss()
            
            Task { @MainActor in
                let stream = engine.compress(files: selectedFiles, to: outputURL, options: options)
                for await progress in stream {
                    if case .failed(let error) = progress.phase {
                        NSLog("[iLab-zip] Compress failed: %@", error.localizedDescription)
                        let alert = NSAlert()
                        alert.messageText = "压缩失败"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.runModal()
                    } else if case .completed = progress.phase {
                        NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
                    }
                }
            }
        }
    }
}
