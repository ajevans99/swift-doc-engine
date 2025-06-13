import Markdown
import MarkdownSupport

// MARK: - LintRule
public protocol LintRule {
    static var id: String { get }
    static var description: String { get }

    /// Return diagnostics for this document.
    func validate(document: Document,
                  index: ASTIndex,
                  context: LintContext) -> [Diagnostic]
}
