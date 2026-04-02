import SwiftUI

/// 左侧目录树视图
struct DirectoryTreeView: View {
    let rootNode: FileTreeNode?
    @Binding var selectedPath: String
    
    /// 记录各节点的展开状态，key 是节点 path
    @State private var expandedPaths: Set<String> = []
    
    var body: some View {
        List {
            if let root = rootNode {
                ForEach(root.children.filter { $0.isDirectory }) { node in
                    DirectoryNodeView(
                        node: node,
                        selectedPath: $selectedPath,
                        expandedPaths: $expandedPaths
                    )
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selectedPath) { newPath in
            expandPathToNode(newPath)
        }
    }
    
    /// 当 selectedPath 改变时，展开从根到目标节点的所有祖先目录
    private func expandPathToNode(_ path: String) {
        guard !path.isEmpty else { return }
        let components = path.split(separator: "/").map(String.init)
        var current = ""
        for component in components {
            current = current.isEmpty ? component : "\(current)/\(component)"
            expandedPaths.insert(current)
        }
    }
}

/// 递归的目录节点视图，使用 DisclosureGroup 以支持编程式展开
struct DirectoryNodeView: View {
    let node: FileTreeNode
    @Binding var selectedPath: String
    @Binding var expandedPaths: Set<String>
    
    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(node.path) },
            set: { newValue in
                if newValue {
                    expandedPaths.insert(node.path)
                } else {
                    expandedPaths.remove(node.path)
                }
            }
        )
    }
    
    var body: some View {
        let dirChildren = node.children.filter { $0.isDirectory }
        
        if dirChildren.isEmpty {
            // 叶子目录 — 无子目录，不需要展开箭头
            nodeLabel
        } else {
            // 有子目录 — 显示可展开的 DisclosureGroup
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(dirChildren) { child in
                    DirectoryNodeView(
                        node: child,
                        selectedPath: $selectedPath,
                        expandedPaths: $expandedPaths
                    )
                }
            } label: {
                nodeLabel
            }
        }
    }
    
    private var nodeLabel: some View {
        Label(node.name, systemImage: "folder.fill")
            .foregroundColor(node.path == selectedPath ? .accentColor : .primary)
            .contentShape(Rectangle())
            .onTapGesture {
                selectedPath = node.path
            }
    }
}

extension FileTreeNode {
    /// 只返回目录子节点（用于 OutlineGroup）
    var directoryChildren: [FileTreeNode]? {
        let dirs = children.filter { $0.isDirectory }
        return dirs.isEmpty ? nil : dirs
    }
}
