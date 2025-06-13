import Foundation
import Markdown

/// High level façade used by applications to read Markdown fragments and
/// apply edits. The engine is stateless aside from a short lived index cache
/// used during a single read/apply cycle.
public final class DocEngine {
    /// Persistence backing the engine.
    let store: DocumentStore
    /// Additional nodes the engine should index.
    let indexOptions: IndexOptions

    /// Index and source text cached for the duration of a single edit so that
    /// `read` and `apply` share work.
    private var cachedIndex: ASTIndex?
    private var cachedText: String?

    public init(store: DocumentStore, indexOptions: IndexOptions = .none) {
        self.store = store
        self.indexOptions = indexOptions
    }

    /// Parse Markdown text with source positions so byte ranges can later be
    /// resolved back to spans. Parsing errors surface as `DocError.parseFailure`.
    private func parse(_ text: String) throws -> Document {
        Document(parsing: text)
    }

    /// Return the AST index for a Markdown document, caching the result for the
    /// duration of a single operation.
    private func index(for text: String) throws -> ASTIndex {
        if let cachedText, cachedText == text, let idx = cachedIndex { return idx }
        let doc = try parse(text)
        let idx = buildIndex(document: doc, text: text, options: indexOptions)
        cachedText = text
        cachedIndex = idx
        return idx
    }

    /// Return the text for a selector.
    ///
    /// `DocEngine` first parses the Markdown and builds an `ASTIndex`. The
    /// selector is resolved against this index so callers can work in terms of
    /// semantic paths rather than brittle byte ranges.
    ///
    /// - Parameters:
    ///   - id: Document identifier understood by the store.
    ///   - selector: Path and optional byte range describing the slice.
    ///   - includeIndex: If `true`, the full index is serialized as JSON
    ///     instead of returning document text. This allows clients to explore
    ///     available selectors. Use by passing a selector of `path: ["*"]`.
    /// - Returns: The `SliceResult` containing the text, byte span, and
    ///   revision string to use for subsequent optimistic writes.
    public func read(_ id: String, selector: Selector, includeIndex: Bool = false) async throws -> SliceResult {
        let (text, rev) = try await store.load(id: id)
        let index = try self.index(for: text)

        if selector.path == ["*"] {
            let json = try JSONEncoder().encode(index.map)
            let txt = String(data: json, encoding: .utf8) ?? ""
            return SliceResult(text: txt, span: 0..<0, revision: rev)
        }

        if let span = index.map[selector.path] {
            let range = span
            guard let start = text.utf8.index(text.utf8.startIndex, offsetBy: range.lowerBound, limitedBy: text.utf8.endIndex),
                  let end = text.utf8.index(text.utf8.startIndex, offsetBy: range.upperBound, limitedBy: text.utf8.endIndex) else {
                throw DocError.rangeOutOfBounds
            }
            let bytes = text.utf8[start..<end]
            let slice = String(decoding: bytes, as: UTF8.self)
            return SliceResult(text: slice, span: range, revision: rev)
        }

        if let fallback = selector.range {
            let start = fallback.lowerBound
            let end = fallback.upperBound
            guard start >= 0 && end <= text.utf8.count else { throw DocError.rangeOutOfBounds }
            let s = text.utf8
            let startIndex = s.index(s.startIndex, offsetBy: start)
            let endIndex = s.index(s.startIndex, offsetBy: end)
            let bytes = s[startIndex..<endIndex]
            let slice = String(decoding: bytes, as: UTF8.self)
            return SliceResult(text: slice, span: fallback, revision: rev)
        }

        throw DocError.selectorMiss(selector.path.joined(separator: "/"))
    }

    /// Apply an edit to the document.
    ///
    /// `DocEngine` performs several steps to keep callers agnostic of the
    /// underlying storage and diff mechanics:
    /// 1. `read` is invoked to resolve byte offsets and obtain the current
    ///    revision.
    /// 2. The new text is spliced into the original at those offsets.
    /// 3. A diff is prepared lazily and passed to the store so it is only
    ///    computed if the optimistic lock succeeds.
    ///
    /// - Parameters:
    ///   - edit: Desired operation and replacement text.
    ///   - id: Document identifier.
    ///   - expectedRevision: Revision returned by a prior call to `read`. Used
    ///     for optimistic locking.
    ///   - author: Optional author string recorded in future store
    ///     implementations.
    /// - Returns: `DiffEnvelope` summarizing the change.
    /// - Throws: `DocError.revisionConflict` if the store has advanced since the
    ///   revision supplied, or other `DocError` values if the selector is
    ///   invalid.
    public func apply(edit: ASTEdit, to id: String, expectedRevision: String, author: String = "unknown") async throws -> DiffEnvelope {
        // Resolve the selector first so we operate on the latest text.
        let original = try await read(id, selector: edit.selector)
        var text = try await store.load(id: id).text

        let span = original.span
        // Splice the new text at the previously located byte range.
        switch edit.op {
        case .delete:
            guard edit.text == nil else { break }
            let utf8 = text.utf8
            let startIdx = utf8.index(utf8.startIndex, offsetBy: span.lowerBound)
            let endIdx = utf8.index(utf8.startIndex, offsetBy: span.upperBound)
            text = String(decoding: utf8[..<startIdx], as: UTF8.self) +
                   String(decoding: utf8[endIdx...], as: UTF8.self)

        case .insert, .replace:
            guard let newText = edit.text else { throw DocError.invalidEdit("missing text") }
            let utf8 = text.utf8
            let startIdx = utf8.index(utf8.startIndex, offsetBy: span.lowerBound)
            let endIdx = utf8.index(utf8.startIndex, offsetBy: span.upperBound)
            var result = String(decoding: utf8[..<startIdx], as: UTF8.self)
            result += newText
            if edit.op == .insert {
                result += String(decoding: utf8[startIdx..<endIdx], as: UTF8.self)
            }
            result += String(decoding: utf8[endIdx...], as: UTF8.self)
            text = result
        }

        // Diff is generated lazily inside `save` so we only pay the cost if the
        // optimistic lock succeeds.
        let diff = SimpleDiff.unified(old: original.text, new: edit.text ?? "")
        let newRev = try await store.save(id: id, newText: text, expectedRevision: expectedRevision) { _, _ in diff }

        // Package up the diff result for clients.
        let change = ChangeSummary(selector: edit.selector, action: edit.op, oldText: original.text, newText: edit.text)
        return DiffEnvelope(docId: id, baseRevision: expectedRevision, newRevision: newRev, changes: [change], patch: diff)
    }
}
