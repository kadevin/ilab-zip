import Foundation

enum FinderSyncConfiguration {

    static func defaultMonitoredDirectoryURLs(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        additionalDirectories: [URL] = FinderSyncMonitoredDirectoryStore().directoryURLs(),
        existingDirectory: (URL) -> Bool = FinderSyncConfiguration.directoryExists
    ) -> [URL] {
        let home = homeDirectory.standardizedFileURL
        let candidates = [
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
            home.appendingPathComponent("Downloads", isDirectory: true),
            URL(fileURLWithPath: "/Volumes", isDirectory: true),
            URL(fileURLWithPath: "/Users/Shared", isDirectory: true)
        ]

        var seen = Set<String>()
        return (candidates + additionalDirectories).compactMap { url in
            let standardized = url.standardizedFileURL
            guard standardized.path != "/", standardized.path != home.path, existingDirectory(standardized) else { return nil }
            guard seen.insert(standardized.path).inserted else { return nil }
            return standardized
        }
    }

    private static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
