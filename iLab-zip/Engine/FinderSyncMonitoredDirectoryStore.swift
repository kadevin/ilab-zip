import Foundation

struct FinderSyncMonitoredDirectoryStore {
    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL = FinderSyncMonitoredDirectoryStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    static func defaultFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("iLab-zip", isDirectory: true)
            .appendingPathComponent("FinderSyncConfig.json", isDirectory: false)
    }

    func directoryURLs() -> [URL] {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(Config.self, from: data) else {
            return []
        }

        return config.paths.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
    }

    func save(_ urls: [URL]) throws {
        var seen = Set<String>()
        let paths = urls.compactMap { url -> String? in
            let path = url.standardizedFileURL.path
            guard seen.insert(path).inserted else { return nil }
            return path
        }

        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(Config(paths: paths))
        try data.write(to: fileURL, options: [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private struct Config: Codable {
        let paths: [String]
    }
}
