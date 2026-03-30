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
        .onChange(of: selection) { newSelection in
            // 检测双击：如果短时间内同一个项被重新选中
            guard newSelection.count == 1, let id = newSelection.first else { return }
            if id == lastSelectedID {
                let elapsed = Date().timeIntervalSince(lastSelectTime)
                if elapsed < 0.5 {
                    // 双击
                    if let entry = entries.first(where: { $0.id == id }) {
                        onDoubleClick(entry)
                    }
                }
            }
            lastSelectedID = id
            lastSelectTime = Date()
        }
    }
    
    @State private var lastSelectedID: ArchiveEntry.ID? = nil
    @State private var lastSelectTime: Date = .distantPast
    
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
