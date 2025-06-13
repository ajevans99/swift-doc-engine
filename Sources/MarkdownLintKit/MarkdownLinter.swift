import Markdown
import MarkdownSupport

// MARK: - Lint entry
public enum MarkdownLinter {
    @MainActor
    public static func lint(_ markdown: String,
                            config: [String: AnyCodable] = [:]) -> [Diagnostic] {
        let document = Document(parsing: markdown)
        let index = MarkdownSupport.buildIndex(document: document, text: markdown)
        let context = LintContext(text: markdown, ast: document, index: index, configuration: config)
        var diagnostics: [Diagnostic] = []
        for rule in RuleRegistry.shared.activeRules {
            diagnostics.append(contentsOf: rule.validate(document: document, index: index, context: context))
        }
        return diagnostics
    }
}
