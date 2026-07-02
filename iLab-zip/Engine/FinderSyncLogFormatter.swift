import Foundation

enum FinderSyncLogFormatter {

    static func itemSummary(_ urls: [URL]) -> String {
        let extensions = Set(urls.map { $0.pathExtension.lowercased() }.filter { !$0.isEmpty })
            .sorted()
            .joined(separator: ",")
        return "count=\(urls.count), extensions=\(extensions.isEmpty ? "none" : extensions)"
    }

    static func commandSummary(action: String, fileCount: Int, hasDestination: Bool) -> String {
        "action=\(action), fileCount=\(fileCount), hasDestination=\(hasDestination)"
    }
}
