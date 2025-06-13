import Markdown
import Foundation

/// Path → byte-span map (headings + fenced blocks)
public struct ASTIndex {
    var map: [[String]: Range<Int>] = [:]
    var headingRanges: [[String]: SourceRange] = [:]
    public subscript(path: [String]) -> Range<Int>? { map[path] }
}

struct HeadingRecord {
    var level: Int
    var slug: String
    var start: Int
    var range: SourceRange
}

struct IndexBuilder: MarkupWalker {
    let text: String
    var path: [String] = []
    var spans: [[String]: Range<Int>] = [:]
    var headingRanges: [[String]: SourceRange] = [:]
    var stack: [HeadingRecord] = []
    var counters: [[String]: [String: Int]] = [:]

    mutating func visitDocument(_ document: Document) {
        descendInto(document)
        finalize(end: text.utf8.count)
    }

    private func byteOffset(of location: SourceLocation) -> Int {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var offset = 0
        let lineIndex = location.line - 1
        for i in 0..<lineIndex { offset += lines[i].utf8.count + 1 }
        offset += max(0, location.column - 1)
        return offset
    }

    private mutating func uniqueSlug(_ base: String) -> String {
        var dict = counters[path] ?? [:]
        let count = dict[base] ?? 0
        dict[base] = count + 1
        counters[path] = dict
        return count == 0 ? base : "\(base)-\(count)"
    }

    mutating func finalize(upTo level: Int, end: Int) {
        while let last = stack.last, last.level >= level {
            _ = stack.popLast()
            let slug = path.removeLast()
            let p = path + [slug]
            spans[p] = last.start..<end
            headingRanges[p] = last.range
        }
    }

    mutating func visitHeading(_ heading: Heading) {
        guard let range = heading.range else { return }
        let start = byteOffset(of: range.lowerBound)
        finalize(upTo: heading.level, end: start)
        let base = Slug.slug(heading.plainText)
        let slug = uniqueSlug(base)
        path.append(slug)
        stack.append(HeadingRecord(level: heading.level, slug: slug, start: start, range: range))
        descendInto(heading)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = codeBlock.range else { return }
        let start = byteOffset(of: range.lowerBound)
        let end = byteOffset(of: range.upperBound)
        var p = path
        let base = codeBlock.language ?? "code"
        let slug = uniqueSlug(base)
        p.append(slug)
        spans[p] = start..<end
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) { descendInto(blockQuote) }
    mutating func visitOrderedList(_ orderedList: OrderedList) { descendInto(orderedList) }
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) { descendInto(unorderedList) }
    mutating func visitListItem(_ listItem: ListItem) { descendInto(listItem) }
    mutating func visitParagraph(_ paragraph: Paragraph) { descendInto(paragraph) }
    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) { descendInto(htmlBlock) }
    mutating func visitCustomBlock(_ custom: CustomBlock) { descendInto(custom) }
    mutating func visitCustomInline(_ custom: CustomInline) { descendInto(custom) }
    mutating func visitEmphasis(_ emphasis: Emphasis) { descendInto(emphasis) }
    mutating func visitStrong(_ strong: Strong) { descendInto(strong) }
    mutating func visitLink(_ link: Link) { descendInto(link) }
    mutating func visitImage(_ image: Image) { descendInto(image) }
    mutating func visitInlineCode(_ inlineCode: InlineCode) { descendInto(inlineCode) }
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) { descendInto(inlineHTML) }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) {}
    mutating func visitLineBreak(_ lineBreak: LineBreak) {}
    mutating func visitText(_ text: Text) {}

    mutating func finalize(end: Int) {
        finalize(upTo: 0, end: end)
    }
}

func buildIndex(document: Document, text: String) -> ASTIndex {
    var builder = IndexBuilder(text: text)
    builder.visit(document)
    var idx = ASTIndex()
    idx.map = builder.spans
    idx.headingRanges = builder.headingRanges
    return idx
}
