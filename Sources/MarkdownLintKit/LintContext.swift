import Markdown
import MarkdownSupport

// MARK: - Infrastructure helpers
public struct LintContext {
    public let text: String
    public let ast: Document
    public let index: ASTIndex
}
