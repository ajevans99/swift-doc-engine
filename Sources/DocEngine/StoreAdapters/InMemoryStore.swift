import Foundation

public actor InMemoryStore: DocumentStore {
    private struct Entry { var text: String; var revision: String }
    private var storage: [String: Entry] = [:]

    public init() {}

    public func load(id: String) async throws -> (text: String, revision: String) {
        guard let entry = storage[id] else { throw DocError.notFound }
        return (entry.text, entry.revision)
    }

    public func save(id: String, newText: String, expectedRevision: String, diffProducer: @Sendable (String, String) -> String) async throws -> String {
        if let entry = storage[id] {
            if entry.revision != expectedRevision {
                throw DocError.revisionConflict(current: entry.revision)
            }
        }
        let revision = UUID().uuidString
        storage[id] = Entry(text: newText, revision: revision)
        return revision
    }
}
