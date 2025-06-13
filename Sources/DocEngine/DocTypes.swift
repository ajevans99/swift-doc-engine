import Foundation

// MARK: - Store abstraction

/// Abstraction for document persistence. Implementations decide where text
/// lives and how revisions are tracked.
public protocol DocumentStore {
    /// Load the current text for an identifier. Implementations throw
    /// `DocError.notFound` when the document does not exist.
    func load(id: String) async throws -> (text: String, revision: String)

    /// Atomically save the new text. The store must compare the passed
    /// `expectedRevision` with its current revision and throw
    /// `DocError.revisionConflict` on mismatch.
    /// - Parameters:
    ///   - diffProducer: Closure that lazily generates a diff once the save
    ///     succeeds. Both parameters are the old and new text.
    func save(id: String,
              newText: String,
              expectedRevision: String,
              diffProducer: @Sendable (String, String) -> String) async throws -> String
}

// MARK: - Core types

/// Identifies a portion of a Markdown document. `path` refers to a normalised
/// AST hierarchy of heading slugs (e.g. `["chapter","introduction"]`).
/// `field` can further specify fenced block tags while `range` acts as a raw
/// byte fallback when the AST path does not resolve.
public struct Selector: Codable, Hashable {
    /// Slugified headings that describe the hierarchy leading to the desired
    /// node. An empty array represents the document root.
    public var path: [String]

    /// Optional fenced block tag such as ``swift``. Used to disambiguate code
    /// blocks under the same heading path.
    public var field: String?

    /// Explicit byte range fallback. Useful when editing arbitrary regions that
    /// are not represented by AST paths.
    public var range: Range<Int>?

    public init(path: [String], field: String? = nil, range: Range<Int>? = nil) {
        self.path = path
        self.field = field
        self.range = range
    }
}

/// Result of slicing a document.
public struct SliceResult: Codable {
    /// Extracted text.
    public var text: String
    /// Byte span that produced the text within the full document.
    public var span: Range<Int>
    /// Revision string returned by the store.
    public var revision: String
}

/// Supported edit operations.
public enum Operation: String, Codable { case insert, replace, delete }

/// Describes a single edit request to be applied to a document.
public struct ASTEdit: Codable {
    /// Operation to perform.
    public var op: Operation
    /// Where in the document the operation applies.
    public var selector: Selector
    /// Replacement text for insert/replace operations.
    public var text: String?

    public init(op: Operation, selector: Selector, text: String? = nil) {
        self.op = op
        self.selector = selector
        self.text = text
    }
}

/// Simplified description of a single change contained in a diff envelope.
public struct ChangeSummary: Codable {
    /// Selector that identified the original content.
    public var selector: Selector
    /// Operation that occurred.
    public var action: Operation
    /// Text before the change.
    public var oldText: String?
    /// Text after the change.
    public var newText: String?
}

/// Aggregates all information describing the result of a successful edit.
public struct DiffEnvelope: Codable {
    public var docId: String
    public var baseRevision: String
    public var newRevision: String
    public var changes: [ChangeSummary]
    /// Unified diff representing the textual change.
    public var patch: String
}

/// Errors thrown by `DocEngine` and store implementations.
public enum DocError: Error, Equatable {
    /// Document could not be found in the store.
    case notFound
    /// Selector did not resolve to any node.
    case selectorMiss(String)
    /// Byte range was outside the bounds of the document.
    case rangeOutOfBounds
    /// Malformed edit request.
    case invalidEdit(String)
    /// Optimistic lock failed - store has moved on to a new revision.
    case revisionConflict(current: String)
    /// Markdown could not be parsed.
    case parseFailure(String)
}
