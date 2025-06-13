import Foundation
import Markdown
import Testing
import MarkdownSupport
@testable import MarkdownLintKit

struct MarkdownLintKitTests {
    @MainActor @Test func allRulesPass() async throws {
        guard let url = Bundle.module.url(forResource: "valid", withExtension: "md", subdirectory: "Fixtures") else {
            throw NSError(domain: "", code: 1)
        }
        RuleRegistry.shared.reset()
        RuleRegistry.shared.registerBuiltInRules()
        let text = try String(contentsOf: url, encoding: .utf8)
        let diags = MarkdownLinter.lint(text, config: [
            "requiredHeadings": AnyCodable(["visual-design", "abilities"]),
            "allowedTags": AnyCodable(["prompt", "notes", "meta"])
        ])
        _ = MarkdownSupport.buildIndex(document: Document(parsing: text), text: text)
        #expect(diags.isEmpty)
    }

    @MainActor @Test func duplicateHeading() async throws {
        RuleRegistry.shared.reset()
        RuleRegistry.shared.registerBuiltInRules()
        let md = "# Story\n\n## Panel 2\n\nText\n\n## Panel 2\nMore"
        let diags = MarkdownLinter.lint(md)
        #expect(diags.count == 1)
        #expect(diags.first?.ruleID == "unique_heading_titles")
    }

    @MainActor @Test func disallowedTag() async throws {
        RuleRegistry.shared.reset()
        RuleRegistry.shared.registerBuiltInRules()
        let md = "# Title\n\n```mermaid\ngraph TD\n```"
        let diags = MarkdownLinter.lint(md, config: [
            "allowedTags": AnyCodable(["prompt", "notes", "meta"])
        ])
        #expect(diags.count == 1)
        #expect(diags.first?.ruleID == "allowed_fenced_tags")
    }

    @MainActor @Test func customRule() async throws {
        RuleRegistry.shared.reset()
        RuleRegistry.shared.registerBuiltInRules()
        RuleRegistry.shared.register(NoBanEmojiRule())
        let diags = MarkdownLinter.lint("# Title\nThis 🚫 should fail.")
        #expect(diags.count == 1)
        #expect(diags.first?.ruleID == "no_ban_emoji")
    }
}

/// Fails if document contains 🚫 emoji anywhere.
struct NoBanEmojiRule: LintRule {
    static let id = "no_ban_emoji"
    static let description = "Disallow the 🚫 emoji in prose"

    func validate(document: Document, index: ASTIndex, context: LintContext) -> [Diagnostic] {
        guard let range = document.range, context.text.contains("🚫") else { return [] }
        return [Diagnostic(severity: .error, message: "🚫 emoji not allowed", range: range, ruleID: Self.id)]
    }
}
