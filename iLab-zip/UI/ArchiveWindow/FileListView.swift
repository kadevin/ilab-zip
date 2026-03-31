import SwiftUI

/// 右侧文件列表视图
struct FileListView: View {
    let entries: [ArchiveEntry]
    @Binding var selection: Set<ArchiveEntry.ID>
    var onDoubleClick: (ArchiveEntry) -> Void
    
    @State private var sortOrder = [KeyPathComparator(\ArchiveEntry.name)]
    
    var sortedEntries: [ArchiveEntry] {
        // 先目录后文件，再按 sortOrder 排序
        let sorted = entries.sorted(using: sortOrder)
        let dirs = sorted.filter { $0.isDirectory }
        let files = sorted.filter { !$0.isDirectory }
        return dirs + files
    }
    
    var body: some View {
        Table(sortedEntries, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(NSLocalizedString("column.name", comment: "名称"), value: \.name) { entry in
                HStack(spacing: 6) {
                    Image(systemName: entry.isDirectory ? "folder.fill" : iconForFile(entry.name))
                        .foregroundColor(entry.isDirectory ? .accentColor : .secondary)
                    Text(entry.name)
                        .lineLimit(1)
                }
            }
            .width(min: 200)
            
            TableColumn(NSLocalizedString("column.size", comment: "大小"), value: \.size) { entry in
                Text(entry.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: Int64(entry.size), countStyle: .file))
                    .foregroundColor(.secondary)
            }
            .width(80)
            
            TableColumn(NSLocalizedString("column.compressedSize", comment: "压缩后"), value: \.compressedSize) { entry in
                Text(entry.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: Int64(entry.compressedSize), countStyle: .file))
                    .foregroundColor(.secondary)
            }
            .width(80)
            
            TableColumn(NSLocalizedString("column.modified", comment: "修改日期")) { entry in
                if let date = entry.modifiedDate {
                    Text(date, style: .date)
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .foregroundColor(.secondary)
                }
            }
            .width(120)
            
            TableColumn(NSLocalizedString("column.type", comment: "类型")) { entry in
                Text(entry.isDirectory ? NSLocalizedString("type.folder", comment: "文件夹") : fileType(entry.name))
                    .foregroundColor(.secondary)
            }
            .width(80)
        }
        .background(
            TableDoubleClickHandler { clickedRow in
                // clickedRow 是 NSTableView 中的行索引，对应 sortedEntries 的索引
                guard clickedRow >= 0, clickedRow < sortedEntries.count else { return }
                let entry = sortedEntries[clickedRow]
                onDoubleClick(entry)
            }
        )
    }
    
    // MARK: - 工具方法
    
    private func iconForFile(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift", "py", "js", "ts", "java", "c", "cpp", "h", "m":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "svg", "webp":
            return "photo"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "pdf":
            return "doc.richtext"
        case "zip", "7z", "rar", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc"
        }
    }
    
    private func fileType(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.uppercased()
        return ext.isEmpty ? NSLocalizedString("type.file", comment: "文件") : "\(ext) \(NSLocalizedString("type.file", comment: "文件"))"
    }
}

// MARK: - NSTableView 双击处理器

/// 通过挂钩底层 NSTableView 的 doubleAction 来可靠地检测双击事件。
/// SwiftUI 的 Table 底层使用 NSTableView，但未暴露双击 API，
/// 所以我们通过 NSViewRepresentable 查找并设置 doubleAction。
struct TableDoubleClickHandler: NSViewRepresentable {
    let action: (_ clickedRow: Int) -> Void
    
    class Coordinator: NSObject {
        var action: (_ clickedRow: Int) -> Void
        
        init(action: @escaping (_ clickedRow: Int) -> Void) {
            self.action = action
        }
        
        @objc func handleDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            guard row >= 0 else { return }
            action(row)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // 延迟查找 NSTableView，确保视图层级已经构建完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let tableView = findTableView(from: view) else {
                NSLog("[iLab-zip] WARNING: 无法找到 NSTableView 来设置双击处理")
                return
            }
            tableView.target = context.coordinator
            tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
    }
    
    /// 从给定视图向上遍历视图层级，查找同一窗口中的 NSTableView
    private func findTableView(from view: NSView) -> NSTableView? {
        // 先尝试向上查找
        var current: NSView? = view
        while let v = current {
            if let tv = v as? NSTableView { return tv }
            // 在当前祖先的子视图中递归查找
            for sibling in (v.superview?.subviews ?? []) where sibling !== v {
                if let found = findTableViewInHierarchy(sibling) {
                    return found
                }
            }
            current = v.superview
        }
        // 最后尝试从窗口的 contentView 查找
        if let contentView = view.window?.contentView {
            return findTableViewInHierarchy(contentView)
        }
        return nil
    }
    
    private func findTableViewInHierarchy(_ view: NSView) -> NSTableView? {
        if let tv = view as? NSTableView { return tv }
        for subview in view.subviews {
            if let found = findTableViewInHierarchy(subview) {
                return found
            }
        }
        return nil
    }
}
