import Testing
@testable import DocEngine

struct DiffTests {
    @Test func simpleDiff() async throws {
        let old = "a\nb\n"
        let new = "a\nc\n"
        let patch = SimpleDiff.unified(old: old, new: new)
        #expect(patch.contains("-b"))
        #expect(patch.contains("+c"))
    }

    @Test func multiLineDiff() async throws {
        let old = "one\ntwo\nthree"
        let new = "one\n2\nthree\nfour"
        let patch = SimpleDiff.unified(old: old, new: new)
        #expect(patch.contains("-two"))
        #expect(patch.contains("+2"))
        #expect(patch.contains("+four"))
    }
}


