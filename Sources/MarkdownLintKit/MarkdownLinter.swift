import Markdown
import MarkdownSupport

// MARK: - Lint entry
public struct MarkdownLinter {
    private let ruleRegistry: RuleRegistry

    public init(ruleRegistry: RuleRegistry) {
        self.ruleRegistry = ruleRegistry
    }

    @MainActor
    public func lint(_ markdown: String) -> [Diagnostic] {
        let document = Document(parsing: markdown)
        let index = MarkdownSupport.buildIndex(document: document, text: markdown)
        let context = LintContext(text: markdown, ast: document, index: index)
        var diagnostics: [Diagnostic] = []
        for rule in ruleRegistry.activeRules {
            diagnostics.append(contentsOf: rule.validate(document: document, index: index, context: context))
        }
        return diagnostics
    }
}
