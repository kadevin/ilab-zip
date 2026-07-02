import Foundation

struct FinderExtensionCommand {
    let action: String
    let files: [String]
    let dest: String?
    let handoffID: UUID?

    init?(url: URL) {
        guard url.scheme == "ilabzip" else { return nil }

        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)
        action = url.host ?? ""

        guard action == "handoff",
              let idValue = params?.queryItems?.first(where: { $0.name == "id" })?.value,
              let id = UUID(uuidString: idValue) else {
            return nil
        }

        handoffID = id
        files = []
        dest = nil
    }
}
