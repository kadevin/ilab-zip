import SwiftUI

/// 左侧目录树视图
struct DirectoryTreeView: View {
    let rootNode: FileTreeNode?
    @Binding var selectedPath: String
    
    var body: some View {
        List {
            if let root = rootNode {
                OutlineGroup(root.children.filter { $0.isDirectory }, children: \.directoryChildren) { node in
                    Label(node.name, systemImage: "folder.fill")
                        .foregroundColor(node.path == selectedPath ? .accentColor : .primary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPath = node.path
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

extension FileTreeNode {
    /// 只返回目录子节点（用于 OutlineGroup）
    var directoryChildren: [FileTreeNode]? {
        let dirs = children.filter { $0.isDirectory }
        return dirs.isEmpty ? nil : dirs
    }
}
