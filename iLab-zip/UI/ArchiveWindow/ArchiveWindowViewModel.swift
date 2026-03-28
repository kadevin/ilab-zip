import SwiftUI

/// 主浏览窗口 ViewModel
@MainActor
final class ArchiveWindowViewModel: ObservableObject {
    @Published var entries: [ArchiveEntry] = []
    @Published var rootNode: FileTreeNode?
    @Published var selectedNode: FileTreeNode?
    @Published var currentPath: String = ""
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showPasswordPrompt: Bool = false
    @Published var showCompressionSheet: Bool = false
    @Published var archiveURL: URL?
    @Published var archivePassword: String?
    
    /// 当前目录下的文件列表（过滤后）
    var displayedEntries: [ArchiveEntry] {
        let filtered = entries.filter { entry in
            if currentPath.isEmpty {
                // 根目录：只显示顶层项目
                return !entry.path.contains("/") || entry.path.components(separatedBy: "/").count == 1
            } else {
                // 子目录：显示以当前路径为前缀的直接子项
                guard entry.path.hasPrefix(currentPath + "/") else { return false }
                let remaining = entry.path.dropFirst(currentPath.count + 1)
                return !remaining.contains("/")
            }
        }
        
        if searchText.isEmpty {
            return filtered
        }
        return filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// 统计信息
    var totalSize: UInt64 {
        displayedEntries.reduce(0) { $0 + $1.size }
    }
    
    var totalCompressedSize: UInt64 {
        displayedEntries.reduce(0) { $0 + $1.compressedSize }
    }
    
    var itemCount: Int {
        displayedEntries.count
    }
    
    var isEncrypted: Bool {
        entries.contains { $0.isEncrypted }
    }
    
    private(set) var engine: ArchiveEngine?
    
    func setEngine(_ engine: ArchiveEngine) {
        self.engine = engine
    }
    
    // MARK: - 打开压缩包
    
    func openArchive(url: URL) async {
        self.archiveURL = url
        self.isLoading = true
        self.errorMessage = nil
        self.currentPath = ""
        
        guard let engine = engine else {
            print("[iLab-zip] ERROR: engine is nil in openArchive!")
            errorMessage = NSLocalizedString("error.engineNotFound", comment: "")
            isLoading = false
            return
        }
        
        print("[iLab-zip] Opening archive: \(url.path)")
        
        // 自动尝试密码
        let autoTry = PasswordAutoTry(engine: engine)
        let result = await autoTry.tryPasswords(for: url)
        
        var password: String? = nil
        switch result {
        case .notEncrypted:
            break
        case .found(let pwd):
            password = pwd
            self.archivePassword = pwd
        case .notFound:
            // 需要用户输入密码
            self.showPasswordPrompt = true
            self.isLoading = false
            return
        }
        
        await loadEntries(password: password)
    }
    
    /// 用户输入密码后重新加载
    func retryWithPassword(_ password: String) async {
        self.archivePassword = password
        await loadEntries(password: password)
    }
    
    private func loadEntries(password: String?) async {
        guard let engine = engine, let url = archiveURL else {
            print("[iLab-zip] loadEntries: engine or url is nil")
            return
        }
        isLoading = true
        
        do {
            print("[iLab-zip] Calling engine.listContents for: \(url.path)")
            let result = try await engine.listContents(of: url, password: password)
            print("[iLab-zip] listContents returned \(result.count) entries")
            self.entries = result
            self.rootNode = buildTree(from: result)
            self.isLoading = false
        } catch {
            print("[iLab-zip] loadEntries error: \(error)")
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
    
    // MARK: - 构建文件树
    
    private func buildTree(from entries: [ArchiveEntry]) -> FileTreeNode {
        let root = FileTreeNode(name: archiveURL?.lastPathComponent ?? "Archive", path: "", isDirectory: true)
        
        for entry in entries {
            let components = entry.path.split(separator: "/").map(String.init)
            var currentNode = root
            var currentPath = ""
            
            for (index, component) in components.enumerated() {
                currentPath = currentPath.isEmpty ? component : "\(currentPath)/\(component)"
                let isLast = index == components.count - 1
                
                if let existing = currentNode.children.first(where: { $0.name == component }) {
                    currentNode = existing
                } else {
                    let isDir = isLast ? entry.isDirectory : true
                    let newNode = FileTreeNode(
                        name: component,
                        path: currentPath,
                        isDirectory: isDir,
                        entry: isLast ? entry : nil
                    )
                    currentNode.children.append(newNode)
                    currentNode = newNode
                }
            }
        }
        
        return root
    }
    
    // MARK: - 导航
    
    func navigateTo(path: String) {
        currentPath = path
    }
    
    func navigateUp() {
        if let lastSlash = currentPath.lastIndex(of: "/") {
            currentPath = String(currentPath[currentPath.startIndex..<lastSlash])
        } else {
            currentPath = ""
        }
    }
}
