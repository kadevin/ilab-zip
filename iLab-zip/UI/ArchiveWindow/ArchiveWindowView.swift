import SwiftUI

/// 主浏览窗口 — WinRAR 风格
struct ArchiveWindowView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ArchiveWindowViewModel()
    @State private var selectedEntries: Set<ArchiveEntry.ID> = []
    
    /// 用于通知去重，防止多窗口重复处理同一文件
    nonisolated(unsafe) static var lastOpenID: String = ""
    
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
            }
            
            // 检查是否有待打开的文件
            if let pendingURL = appState.pendingArchiveURL {
                appState.pendingArchiveURL = nil
                Task { await viewModel.openArchive(url: pendingURL) }
            }
            
            // 设置工具栏 autosave
            setupToolbarAutosave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openArchive)) { notification in
            if let url = notification.object as? URL {
                // 用 UUID 去重：同一通知只处理一次
                let notifID = ObjectIdentifier(notification as AnyObject)
                let key = "\(url.path)_\(Date().timeIntervalSince1970)"
                guard ArchiveWindowView.lastOpenID != url.path || !viewModel.isLoading else { return }
                ArchiveWindowView.lastOpenID = url.path
                
                NSLog("[iLab-zip] Processing openArchive: %@", url.path)
                if viewModel.engine == nil, let engine = appState.engine {
                    viewModel.setEngine(engine)
                }
                Task { await viewModel.openArchive(url: url) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .finderExtensionAction)) { notification in
            if let url = notification.object as? URL {
                NSLog("[iLab-zip] Received finderExtensionAction: %@", url.absoluteString)
                appState.handleFinderExtensionURL(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSplitCompress)) { notification in
            if let files = notification.userInfo?["files"] as? [URL] {
                NSLog("[iLab-zip] showSplitCompress: %d files", files.count)
                viewModel.splitCompressFiles = files
                viewModel.showCompressionSheet = true
            }
        }
        .sheet(isPresented: $viewModel.showPasswordPrompt) {
            PasswordPromptView { password in
                Task { await viewModel.retryWithPassword(password) }
            }
        }
        .sheet(isPresented: $viewModel.showCompressionSheet) {
            CompressionSheetView(
                presetFiles: viewModel.splitCompressFiles,
                defaultSplit: viewModel.splitCompressFiles != nil
            )
            .environmentObject(appState)
            .onDisappear {
                viewModel.splitCompressFiles = nil
            }
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
            
            // 垂直分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 1, height: 20)
                .padding(.horizontal, 4)
            
            Button {
                addFilesToArchive()
            } label: {
                Label("添加", systemImage: "plus.rectangle.on.folder")
            }
            .disabled(viewModel.archiveURL == nil)
            
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
    
    /// 设置工具栏显示模式持久化（图标/图标+文字）
    private func setupToolbarAutosave() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let window = NSApp.windows.first(where: { $0.isKeyWindow || $0.isMainWindow }),
                  let toolbar = window.toolbar else { return }
            toolbar.autosavesConfiguration = true
            
            // 恢复上次保存的显示模式
            let savedMode = UserDefaults.standard.integer(forKey: "toolbarDisplayMode")
            if savedMode > 0, let mode = NSToolbar.DisplayMode(rawValue: UInt(savedMode)) {
                toolbar.displayMode = mode
            }
            
            // 监听显示模式变化并自动保存
            ToolbarObserver.shared.observe(toolbar: toolbar)
        }
    }
    
    private func handleDoubleClick(_ entry: ArchiveEntry) {
        if entry.isDirectory {
            viewModel.navigateTo(path: entry.path)
        }
    }
    
    private func extractAll() {
        guard let engine = appState.engine, let archiveURL = viewModel.archiveURL else {
            NSLog("[iLab-zip] extractAll: engine or archiveURL is nil")
            return
        }
        
        // 直接解压到压缩文件所在目录的同名子文件夹
        let archiveDir = archiveURL.deletingLastPathComponent()
        let archiveName = archiveURL.deletingPathExtension().lastPathComponent
        let dest = archiveDir.appendingPathComponent(archiveName)
        
        // 创建目标文件夹
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        
        // 获取选中文件的路径
        let selected = getSelectedPaths()
        NSLog("[iLab-zip] extractAll to: %@, selected: %d files", dest.path, selected.count)
        performExtraction(engine: engine, archiveURL: archiveURL, destination: dest, selectedPaths: selected)
    }
    
    private func extractToLocation() {
        guard let engine = appState.engine, let archiveURL = viewModel.archiveURL else {
            NSLog("[iLab-zip] extractToLocation: engine or archiveURL is nil")
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
            let selected = self.getSelectedPaths()
            NSLog("[iLab-zip] extractToLocation to: %@, selected: %d files", dest.path, selected.count)
            self.performExtraction(engine: engine, archiveURL: archiveURL, destination: dest, selectedPaths: selected)
        }
    }
    
    /// 获取用户选中的文件路径
    private func getSelectedPaths() -> [String] {
        guard !selectedEntries.isEmpty else { return [] }
        return viewModel.entries
            .filter { selectedEntries.contains($0.id) }
            .map { $0.path }
    }
    
    private func performExtraction(engine: ArchiveEngine, archiveURL: URL, destination: URL, selectedPaths: [String] = []) {
        Task { @MainActor in
            viewModel.isLoading = true
            viewModel.errorMessage = nil
            
            let stream: AsyncStream<ArchiveProgress>
            if selectedPaths.isEmpty {
                // 解压全部
                stream = engine.extract(archive: archiveURL, to: destination, password: viewModel.archivePassword)
            } else {
                // 只解压选中的文件
                stream = engine.extractSelected(archive: archiveURL, entries: selectedPaths, to: destination, password: viewModel.archivePassword)
            }
            
            for await progress in stream {
                switch progress.phase {
                case .completed:
                    viewModel.isLoading = false
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destination.path)
                    NSLog("[iLab-zip] Extract completed to: %@", destination.path)
                    
                case .failed(let error):
                    viewModel.isLoading = false
                    viewModel.errorMessage = error.localizedDescription
                    NSLog("[iLab-zip] Extract failed: %@", error.localizedDescription)
                    
                case .processing:
                    break
                    
                case .preparing:
                    break
                    
                case .finishing:
                    break
                    
                case .cancelled:
                    viewModel.isLoading = false
                }
            }
            
            viewModel.isLoading = false
        }
    }
    
    private func addFilesToArchive() {
        guard let engine = appState.engine, let archiveURL = viewModel.archiveURL else {
            NSLog("[iLab-zip] addFilesToArchive: engine or archiveURL is nil")
            return
        }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "添加"
        panel.message = "选择要添加到压缩包的文件或文件夹"
        
        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            let filesToAdd = panel.urls
            NSLog("[iLab-zip] Adding %d items to archive: %@", filesToAdd.count, archiveURL.path)
            
            Task { @MainActor in
                viewModel.isLoading = true
                viewModel.errorMessage = nil
                
                let stream = engine.addToArchive(archive: archiveURL, files: filesToAdd, password: viewModel.archivePassword)
                
                for await progress in stream {
                    switch progress.phase {
                    case .completed:
                        NSLog("[iLab-zip] Add to archive completed")
                        // 重新加载文件列表
                        await viewModel.openArchive(url: archiveURL)
                        
                    case .failed(let error):
                        viewModel.isLoading = false
                        viewModel.errorMessage = error.localizedDescription
                        NSLog("[iLab-zip] Add to archive failed: %@", error.localizedDescription)
                        
                    default:
                        break
                    }
                }
                
                viewModel.isLoading = false
            }
        }
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
