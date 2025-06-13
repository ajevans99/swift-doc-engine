import Testing
@testable import DocEngine

struct DocEngineTests {
    @Test func readSlice() async throws {
        let store = InMemoryStore()
        _ = try await store.save(id: "doc", newText: "# Title\n\nHello", expectedRevision: "", diffProducer: {_,_ in ""})
        let engine = DocEngine(store: store)
        let selector = Selector(path: ["title"])
        let slice = try await engine.read("doc", selector: selector)
        #expect(slice.text.contains("Title"))
    }

    @Test func applyReplace() async throws {
        let store = InMemoryStore()
        let rev = try await store.save(id: "doc", newText: "Hello", expectedRevision: "", diffProducer: {_,_ in ""})
        let engine = DocEngine(store: store)
        let edit = ASTEdit(op: .replace, selector: Selector(path: ["x"], range: 0..<5), text: "Hi")
        let env = try await engine.apply(edit: edit, to: "doc", expectedRevision: rev)
        #expect(env.patch.contains("-Hello"))
        #expect(env.patch.contains("+Hi"))
    }

    @Test func customDiffProducer() async throws {
        actor MockStore: DocumentStore {
            var savedDiff: String?
            var text: String = ""

            func load(id: String) async throws -> (text: String, revision: String) {
                (text, "0")
            }

            func save(id: String, newText: String, expectedRevision: String, diffProducer: @Sendable (String, String) -> String) async throws -> String {
                savedDiff = diffProducer(text, newText)
                text = newText
                return "1"
            }
        }
        let store = MockStore()
        let engine = DocEngine(store: store)
        let _ = try await engine.apply(edit: ASTEdit(op: .insert, selector: Selector(path: ["*"], range: 0..<0), text: "X"), to: "doc", expectedRevision: "0")
        let diff = await store.savedDiff
        #expect(diff?.contains("+X") == true)
    }

    @Test func revisionConflict() async throws {
        let store = InMemoryStore()
        let rev1 = try await store.save(id: "doc", newText: "Hello", expectedRevision: "", diffProducer: {_,_ in ""})
        _ = try await store.save(id: "doc", newText: "World", expectedRevision: rev1, diffProducer: {_,_ in ""})
        let engine = DocEngine(store: store)
        let edit = ASTEdit(op: .replace, selector: Selector(path: ["*"], range: 0..<5), text: "Hi")
        do {
            _ = try await engine.apply(edit: edit, to: "doc", expectedRevision: rev1)
            #expect(false)
        } catch DocError.revisionConflict {
            #expect(true)
        }
    }

    @Test func unicodeRange() async throws {
        let store = InMemoryStore()
        _ = try await store.save(id: "u", newText: "😀 Hello", expectedRevision: "", diffProducer: {_,_ in ""})
        let engine = DocEngine(store: store)
        let slice = try await engine.read("u", selector: Selector(path: ["none"], range: 0..<4))
        #expect(slice.text == "😀")
    }
}




