import Foundation

public final class FileStore: DocumentStore {
    private let baseURL: URL

    public init(directory: URL) {
        self.baseURL = directory
    }

    public func load(id: String) async throws -> (text: String, revision: String) {
        let url = baseURL.appendingPathComponent(id)
        guard let data = try? Data(contentsOf: url) else { throw DocError.notFound }
        let text = String(decoding: data, as: UTF8.self)
        let revision = try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
        let revString = revision.map { String($0.timeIntervalSince1970) } ?? "0"
        return (text, revString)
    }

    public func save(id: String, newText: String, expectedRevision: String, diffProducer: @Sendable (String, String) -> String) async throws -> String {
        let url = baseURL.appendingPathComponent(id)
        var currentRevision = "0"
        if FileManager.default.fileExists(atPath: url.path) {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let date = attrs[.modificationDate] as? Date {
                currentRevision = String(date.timeIntervalSince1970)
            }
            if currentRevision != expectedRevision {
                throw DocError.revisionConflict(current: currentRevision)
            }
        }
        try newText.write(to: url, atomically: true, encoding: .utf8)
        let revString = String(Date().timeIntervalSince1970)
        return revString
    }
}
