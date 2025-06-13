import Foundation
import Testing
@testable import DocEngine

struct IntegrationTests {
    @Test func replaceSection() async throws {
        guard let url = Bundle.module.url(forResource: "advanced", withExtension: "md", subdirectory: "Fixtures") else {
            throw DocError.notFound
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        let store = InMemoryStore()
        let rev = try await store.save(id: "doc", newText: text, expectedRevision: "", diffProducer: {_,_ in ""})
        let engine = DocEngine(store: store)

        let selector = Selector(path: ["title","section-a"])
        let edit = ASTEdit(op: .replace, selector: selector, text: "Changed")
        let envelope = try await engine.apply(edit: edit, to: "doc", expectedRevision: rev)
        #expect(envelope.changes.first?.newText == "Changed")
    }

    @Test func mockStoreInteractions() async throws {
        actor MockStore: DocumentStore {
            var loadCalls = 0
            var saveCalls = 0
            var text: String = "initial"

            func load(id: String) async throws -> (text: String, revision: String) {
                loadCalls += 1
                return (text, "r1")
            }

            func save(id: String, newText: String, expectedRevision: String, diffProducer: @Sendable (String, String) -> String) async throws -> String {
                saveCalls += 1
                text = newText
                _ = diffProducer("", newText)
                return "r2"
            }
        }

        let store = MockStore()
        let engine = DocEngine(store: store)
        _ = try await engine.apply(edit: ASTEdit(op: .replace, selector: Selector(path: ["*"], range: 0..<0), text: "new"), to: "doc", expectedRevision: "r1")
        let loads = await store.loadCalls
        let saves = await store.saveCalls
        #expect(loads > 0)
        #expect(saves == 1)
    }
}



