import SwiftUI

/// 主浏览窗口 — WinRAR 风格
struct ArchiveWindowView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ArchiveWindowViewModel()
    @State private var selectedEntries: Set<ArchiveEntry.ID> = []
    
    var body: some View {
        NavigationSplitView {
            // 左侧 — 目录树
            DirectoryTreeView(
                rootNode: viewModel.rootNode,
                selectedPath: $viewModel.currentPath
            )
            .frame(minWidth: 200)
        } detail: {
            // 右侧 — 文件列表
            VStack(spacing: 0) {
                if viewModel.entries.isEmpty && !viewModel.isLoading {
                    // 空状态 — 引导用户
                    VStack(spacing: 16) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("拖拽或打开压缩文件以查看内容")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        
                        Button("打开压缩文件...") {
                            openFileDialog()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    FileListView(
                        entries: viewModel.displayedEntries,
                        selection: $selectedEntries,
                        onDoubleClick: handleDoubleClick
                    )
                }
                
                Divider()
                
                // 状态栏
                statusBar
            }
        }
        .navigationTitle(viewModel.archiveURL?.lastPathComponent ?? NSLocalizedString("app.name", comment: "如压"))
        .toolbar {
            toolbarContent
        }
        .searchable(text: $viewModel.searchText, prompt: Text(NSLocalizedString("search.prompt", comment: "搜索文件...")))
        .onAppear {
            // 设置引擎
            if let engine = appState.engine {
                viewModel.setEngine(engine)
                print("[iLab-zip] Engine set in ArchiveWindowView.onAppear")
            } else {
                print("[iLab-zip] WARNING: No engine available in onAppear!")
            }
            
            // 检查是否有待打开的文件
            if let pendingURL = appState.pendingArchiveURL {
                print("[iLab-zip] Opening pending archive: \(pendingURL.path)")
                appState.pendingArchiveURL = nil
                Task { await viewModel.openArchive(url: pendingURL) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openArchive)) { notification in
            if let url = notification.object as? URL {
                print("[iLab-zip] Received openArchive notification: \(url.path)")
                // 确保引擎已设置
                if viewModel.engine == nil, let engine = appState.engine {
                    viewModel.setEngine(engine)
                }
                Task { await viewModel.openArchive(url: url) }
            }
        }
        .sheet(isPresented: $viewModel.showPasswordPrompt) {
            PasswordPromptView { password in
                Task { await viewModel.retryWithPassword(password) }
            }
        }
        .sheet(isPresented: $viewModel.showCompressionSheet) {
            CompressionSheetView()
                .environmentObject(appState)
        }
        .alert(NSLocalizedString("error.title", comment: "错误"), isPresented: .constant(viewModel.errorMessage != nil)) {
            Button(NSLocalizedString("button.ok", comment: "确定")) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView(NSLocalizedString("loading", comment: "加载中..."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
        }
        .frame(minWidth: 800, minHeight: 500)
    }
    
    // MARK: - 工具栏
    
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                extractAll()
            } label: {
                Label(NSLocalizedString("toolbar.extract", comment: "解压"), systemImage: "arrow.down.doc")
            }
            .disabled(viewModel.entries.isEmpty)
            
            Button {
                extractToLocation()
            } label: {
                Label(NSLocalizedString("toolbar.extractTo", comment: "解压到..."), systemImage: "arrow.down.doc.fill")
            }
            .disabled(viewModel.entries.isEmpty)
            
            Divider()
            
            Button {
                viewModel.showCompressionSheet = true
            } label: {
                Label(NSLocalizedString("toolbar.compress", comment: "压缩"), systemImage: "archivebox")
            }
        }
        
        ToolbarItem(placement: .navigation) {
            Button {
                viewModel.navigateUp()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(viewModel.currentPath.isEmpty)
        }
    }
    
    // MARK: - 状态栏
    
    var statusBar: some View {
        HStack {
            Text(String(format: NSLocalizedString("status.items", comment: "%d 个对象"), viewModel.itemCount))
            Text("，")
            Text(String(format: NSLocalizedString("status.size", comment: "共 %@"), ByteCountFormatter.string(fromByteCount: Int64(viewModel.totalSize), countStyle: .file)))
            Text(String(format: NSLocalizedString("status.compressedSize", comment: "（压缩后 %@）"), ByteCountFormatter.string(fromByteCount: Int64(viewModel.totalCompressedSize), countStyle: .file)))
            
            Spacer()
            
            if viewModel.isEncrypted {
                Label(NSLocalizedString("status.encrypted", comment: "AES-256 加密"), systemImage: "lock.fill")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
    
    // MARK: - 操作
    
    private func openFileDialog() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.data]
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                await viewModel.openArchive(url: url)
            }
        }
    }
    
    private func handleDoubleClick(_ entry: ArchiveEntry) {
        if entry.isDirectory {
            viewModel.navigateTo(path: entry.path)
        }
    }
    
    private func extractAll() {
        guard let engine = appState.engine, let archiveURL = viewModel.archiveURL else {
            print("[iLab-zip] extractAll: engine or archiveURL is nil")
            return
        }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = NSLocalizedString("button.extract", comment: "解压")
        panel.message = NSLocalizedString("extract.selectDestination", comment: "选择解压目标文件夹")
        
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            
            Task { @MainActor in
                viewModel.isLoading = true
                viewModel.errorMessage = nil
                
                let stream = engine.extract(archive: archiveURL, to: dest, password: viewModel.archivePassword)
                
                for await progress in stream {
                    switch progress.phase {
                    case .completed:
                        viewModel.isLoading = false
                        // 解压完成，在 Finder 中显示
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dest.path)
                        print("[iLab-zip] Extract completed to: \(dest.path)")
                        
                    case .failed(let error):
                        viewModel.isLoading = false
                        viewModel.errorMessage = error.localizedDescription
                        print("[iLab-zip] Extract failed: \(error)")
                        
                    case .processing:
                        // 进度更新（未来可接入 ProgressWindowView）
                        print("[iLab-zip] Extract progress: \(progress.percentage)% - \(progress.currentFile ?? "")")
                        
                    case .preparing:
                        print("[iLab-zip] Extract preparing...")
                        
                    case .finishing:
                        print("[iLab-zip] Extract finishing...")
                        
                    case .cancelled:
                        viewModel.isLoading = false
                        print("[iLab-zip] Extract cancelled")
                    }
                }
                
                viewModel.isLoading = false
            }
        }
    }
    
    private func extractToLocation() {
        extractAll()
    }
    
    private func handleFileDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    await viewModel.openArchive(url: url)
                }
            }
        }
        return true
    }
}
