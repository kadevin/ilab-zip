import AppKit
import Foundation

struct FinderExtensionHandoff: Codable, Equatable {
    let action: String
    let files: [String]
    let dest: String?
}

struct FinderExtensionHandoffStore {
    private static let pasteboardPrefix = "com.ilab.iLab-zip.finder-handoff."

    private let pasteboardPrefix: String

    init(
        pasteboardPrefix: String = FinderExtensionHandoffStore.pasteboardPrefix
    ) {
        self.pasteboardPrefix = pasteboardPrefix
    }

    func writeURL(for handoff: FinderExtensionHandoff) throws -> URL {
        let id = UUID()
        let data = try JSONEncoder().encode(handoff)
        let pasteboard = NSPasteboard(name: pasteboardName(for: id))
        pasteboard.clearContents()
        guard pasteboard.setData(data, forType: .finderExtensionHandoff) else {
            throw HandoffError.writeFailed
        }

        var components = URLComponents()
        components.scheme = "ilabzip"
        components.host = "handoff"
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]

        guard let url = components.url else {
            throw HandoffError.invalidURL
        }
        return url
    }

    func readAndDelete(id: UUID) throws -> FinderExtensionHandoff {
        let pasteboard = NSPasteboard(name: pasteboardName(for: id))
        guard let data = pasteboard.data(forType: .finderExtensionHandoff) else {
            throw HandoffError.notFound
        }
        let handoff = try JSONDecoder().decode(FinderExtensionHandoff.self, from: data)
        pasteboard.clearContents()
        return handoff
    }

    func containsHandoff(id: UUID) -> Bool {
        NSPasteboard(name: pasteboardName(for: id)).data(forType: .finderExtensionHandoff) != nil
    }

    private func pasteboardName(for id: UUID) -> NSPasteboard.Name {
        NSPasteboard.Name(pasteboardPrefix + id.uuidString)
    }

    enum HandoffError: Error {
        case invalidURL
        case notFound
        case writeFailed
    }
}

private extension NSPasteboard.PasteboardType {
    static let finderExtensionHandoff = NSPasteboard.PasteboardType("com.ilab.iLab-zip.finder-handoff")
}
