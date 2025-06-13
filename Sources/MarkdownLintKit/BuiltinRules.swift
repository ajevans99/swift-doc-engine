import Markdown
import MarkdownSupport

struct RequiredHeadingRule: LintRule {
    static let id = "required_heading"
    static let description = "Required headings must exist"

    func validate(document: Document, index: ASTIndex, context: LintContext) -> [Diagnostic] {
        guard let arr = context.configuration["requiredHeadings"]?.value as? [String], !arr.isEmpty else { return [] }
        let range = document.range ?? SourceRange(start: .init(line: 1, column: 1, source: nil), end: .init(line: 1, column: 1, source: nil))
        return arr.compactMap { slug in
            let exists = index.headingRanges.keys.contains { $0.last == slug }
            return exists ? nil : Diagnostic(
                severity: .error,
                message: "Missing required heading \"\(slug)\"",
                range: range,
                ruleID: Self.id)
        }
    }
}

struct UniqueHeadingTitlesRule: LintRule {
    static let id = "unique_heading_titles"
    static let description = "Headings must be unique at the same depth"

    func validate(document: Document, index: ASTIndex, context: LintContext) -> [Diagnostic] {
        var walker = DuplicateWalker()
        walker.visit(document)
        return walker.diagnostics
    }

    private struct DuplicateWalker: MarkupWalker {
        var diagnostics: [Diagnostic] = []
        var path: [String] = []
        var stack: [(level: Int, slug: String)] = []
        var sets: [[String]: Set<String>] = [:]

        mutating func visitHeading(_ heading: Heading) {
            while let last = stack.last, last.level >= heading.level { stack.removeLast(); path.removeLast() }
            let base = Slug.slug(heading.plainText)
            var set = sets[path] ?? Set<String>()
            if set.contains(base), let range = heading.range {
                diagnostics.append(Diagnostic(severity: .error, message: "Duplicate heading \"\(heading.plainText)\" at same depth", range: range, ruleID: UniqueHeadingTitlesRule.id))
            } else {
                set.insert(base)
                sets[path] = set
            }
            stack.append((heading.level, base))
            path.append(base)
            descendInto(heading)
        }
    }
}

struct AllowedFencedTagsRule: LintRule {
    static let id = "allowed_fenced_tags"
    static let description = "Allowed fenced block tags"

    func validate(document: Document, index: ASTIndex, context: LintContext) -> [Diagnostic] {
        guard let tags = context.configuration["allowedTags"]?.value as? [String], !tags.isEmpty else { return [] }
        var diags: [Diagnostic] = []
        var walker = CodeWalker(tags: Set(tags)) { block in
            if let range = block.range {
                diags.append(Diagnostic(severity: .error, message: "Disallowed fenced block tag \"\(block.language ?? "")\"", range: range, ruleID: Self.id))
            }
        }
        walker.visit(document)
        return diags
    }

    private struct CodeWalker: MarkupWalker {
        let tags: Set<String>
        var onError: (CodeBlock) -> Void
        func visitCodeBlock(_ block: CodeBlock) {
            if let lang = block.language, !tags.contains(lang) { onError(block) }
        }
    }
}

struct NoEmptySectionRule: LintRule {
    static let id = "no_empty_section"
    static let description = "Headings must contain body text"

    func validate(document: Document, index: ASTIndex, context: LintContext) -> [Diagnostic] {
        var diagnostics: [Diagnostic] = []
        for (path, span) in index.map {
            guard path.count > 0, let headingRange = index.headingRanges[path] else { continue }
            let start = byteOffset(of: headingRange.upperBound, in: context.text)
            if start >= span.upperBound { continue }
            let startIdx = context.text.utf8.index(context.text.utf8.startIndex, offsetBy: start)
            let endIdx = context.text.utf8.index(context.text.utf8.startIndex, offsetBy: span.upperBound)
            let body = String(decoding: context.text.utf8[startIdx..<endIdx], as: UTF8.self)
            if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(Diagnostic(severity: .warning, message: "Section \"\(path.last!)\" has no content", range: headingRange, ruleID: Self.id))
            }
        }
        return diagnostics
    }

    private func byteOffset(of loc: SourceLocation, in text: String) -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var offset = 0
        let lineIndex = loc.line - 1
        for i in 0..<lineIndex { offset += lines[i].utf8.count + 1 }
        offset += max(0, loc.column - 1)
        return offset
    }
}
