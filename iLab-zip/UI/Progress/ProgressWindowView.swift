import SwiftUI

/// 解压/压缩进度窗口
struct ProgressWindowView: View {
    @ObservedObject var progressState: ProgressState
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            Text(progressState.title)
                .font(.headline)
            
            // 当前文件名
            if let currentFile = progressState.currentFile {
                Text(currentFile)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 进度条
            ProgressView(value: progressState.percentage, total: 100) {
                HStack {
                    Text(String(format: "%.0f%%", progressState.percentage))
                    Spacer()
                    if let speed = progressState.speed {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // 剩余时间
            if let remaining = progressState.estimatedTimeRemaining {
                Text(String(format: NSLocalizedString("progress.remaining", comment: "剩余时间：%@"), formatTimeInterval(remaining)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 取消按钮
            Button(NSLocalizedString("button.cancel", comment: "取消")) {
                progressState.cancel()
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(width: 380)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

/// 进度状态模型
@MainActor
final class ProgressState: ObservableObject {
    @Published var title: String
    @Published var percentage: Double = 0
    @Published var currentFile: String?
    @Published var speed: Double?
    @Published var estimatedTimeRemaining: TimeInterval?
    @Published var isCompleted: Bool = false
    
    private var cancelAction: (() -> Void)?
    
    init(title: String, cancelAction: @escaping () -> Void) {
        self.title = title
        self.cancelAction = cancelAction
    }
    
    func update(from progress: ArchiveProgress) {
        self.percentage = progress.percentage
        self.currentFile = progress.currentFile
        self.speed = progress.speed
        self.estimatedTimeRemaining = progress.estimatedTimeRemaining
        
        if case .completed = progress.phase {
            self.isCompleted = true
        }
    }
    
    func cancel() {
        cancelAction?()
    }
}
