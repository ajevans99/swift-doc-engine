import Markdown

// MARK: - Infrastructure helpers
public struct LintContext {
    public let text: String
    public let ast: Document
    public let index: ASTIndex
    public let configuration: [String: AnyCodable]
}
