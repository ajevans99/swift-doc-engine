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
        let registry = RuleRegistry(rules: [
            RequiredHeadingRule(headings: ["visual-design", "abilities"]),
            UniqueHeadingTitlesRule(),
            AllowedFencedTagsRule(allowedTags: ["prompt", "notes", "meta"]),
            NoEmptySectionRule()
        ])
        let linter = MarkdownLinter(ruleRegistry: registry)
        let text = try String(contentsOf: url, encoding: .utf8)
        let diags = linter.lint(text)
        _ = MarkdownSupport.buildIndex(document: Document(parsing: text), text: text)
        #expect(diags.isEmpty)
    }

    @MainActor @Test func duplicateHeading() async throws {
        let registry = RuleRegistry(rules: [
            UniqueHeadingTitlesRule()
        ])
        let linter = MarkdownLinter(ruleRegistry: registry)
        let md = "# Story\n\n## Panel 2\n\nText\n\n## Panel 2\nMore"
        let diags = linter.lint(md)
        #expect(diags.count == 1)
        #expect(diags.first?.ruleID == "unique_heading_titles")
    }

    @MainActor @Test func disallowedTag() async throws {
        let registry = RuleRegistry(rules: [
            AllowedFencedTagsRule(allowedTags: ["prompt", "notes", "meta"])
        ])
        let linter = MarkdownLinter(ruleRegistry: registry)
        let md = "# Title\n\n```mermaid\ngraph TD\n```"
        let diags = linter.lint(md)
        #expect(diags.count == 1)
        #expect(diags.first?.ruleID == "allowed_fenced_tags")
    }

    @MainActor @Test func customRule() async throws {
        let registry = RuleRegistry(rules: [
            NoBanEmojiRule()
        ])
        let linter = MarkdownLinter(ruleRegistry: registry)
        let diags = linter.lint("# Title\nThis 🚫 should fail.")
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
