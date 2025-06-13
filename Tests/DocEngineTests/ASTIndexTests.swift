import Testing
@testable import DocEngine
import Markdown
import Foundation

struct ASTIndexTests {
    @Test func buildsMap() async throws {
        let text = "# Head One\n\n## Sub Head\n\n```swift\ncode\n```"
        let document = Document(parsing: text)
        let index = buildIndex(document: document, text: text)
        #expect(index.map[["head-one"]] != nil)
        #expect(index.map[["head-one","sub-head"]] != nil)
        #expect(index.map[["head-one","sub-head","code-swift"]] != nil)
    }

    @Test func slugNormalisation() async throws {
        let text = "#   S p a c e s  ###\n"
        let doc = Document(parsing: text)
        let index = buildIndex(document: doc, text: text)
        #expect(index.map[["s-p-a-c-e-s"]] != nil)
    }

    @Test func nestedPaths() async throws {
        guard let url = Bundle.module.url(forResource: "nested", withExtension: "md", subdirectory: "Fixtures") else { throw DocError.notFound }
        let text = try String(contentsOf: url, encoding: .utf8)
        let doc = Document(parsing: text)
        let idx = buildIndex(document: doc, text: text, options: [.paragraphs])
        #expect(idx.map[["level1","level2","level3","para"]] != nil)
    }
}



