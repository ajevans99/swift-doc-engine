import Foundation
import Markdown


/// Mapping of Markdown heading paths to byte ranges within the source text.
/// Headings are slugified and stacked as a path. Fenced code blocks add a
/// trailing element starting with ``\``. Only nodes with concrete source spans
/// are recorded.
public struct ASTIndex {
    /// Convenience alias for a byte range.
    public typealias Span = Range<Int>
    /// Dictionary storing `[slugPath] -> span` pairs.
    public var map: [ [String] : Span ] = [:]
    /// Ranges of heading declarations in source.
    public var headingRanges: [ [String] : SourceRange ] = [:]

    public subscript(path: [String]) -> Span? {
        map[path]
    }
}

/// Options controlling which extra nodes are indexed beyond headings and code blocks.
public struct IndexOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// Include paragraph nodes.
    public static let paragraphs = IndexOptions(rawValue: 1 << 0)
    /// Include list items.
    public static let listItems  = IndexOptions(rawValue: 1 << 1)
    /// Include block quotes.
    public static let blockQuotes = IndexOptions(rawValue: 1 << 2)
    public static let none: IndexOptions = []
}

/// Walks the Markdown AST collecting byte ranges for headings and fenced
/// code blocks. All other node types are simply descended into so the full
/// hierarchy is visited.
struct IndexBuilder: MarkupWalker {
    let text: String
    let options: IndexOptions
    var path: [String] = []
    var spans: [ [String] : Range<Int> ] = [:]
    var headingRanges: [ [String] : SourceRange ] = [:]
    /// Tracks the number of occurrences of a slug at a given path so siblings
    /// receive stable unique identifiers like `para-1` or `code-swift-2`.
    var counters: [ [String] : [String: Int] ] = [:]

    private var headingStack: [(level: Int, slug: String, start: Int, range: SourceRange)] = []

    mutating func visitDocument(_ document: Document) {
        descendInto(document)
        finalize(end: text.utf8.count)
    }

    init(text: String, options: IndexOptions) {
        self.text = text
        self.options = options
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
        let key = path
        var dict = counters[key] ?? [:]
        let count = dict[base] ?? 0
        dict[base] = count + 1
        counters[key] = dict
        return count == 0 ? base : "\(base)-\(count)"
    }

    mutating func finalize(upTo level: Int, end: Int) {
        while let last = headingStack.last, last.level >= level {
            _ = headingStack.popLast()
            let slug = path.removeLast()
            let p = path + [slug]
            spans[p] = last.start..<end
            headingRanges[p] = last.range
            spans[[slug]] = last.start..<end
            headingRanges[[slug]] = last.range
        }
    }

    mutating func visitHeading(_ heading: Heading) {
        guard let range = heading.range else { return }
        let start = byteOffset(of: range.lowerBound)
        finalize(upTo: heading.level, end: start)
        let base = Slug.slug(heading.plainText)
        let slug = uniqueSlug(base)
        path.append(slug)
        headingStack.append((heading.level, slug, start, range))
        descendInto(heading)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = codeBlock.range else { return }
        let start = byteOffset(of: range.lowerBound)
        let end = byteOffset(of: range.upperBound)
        var p = path
        var slug = "code"
        if let info = codeBlock.language {
            slug = "code-" + info
        }
        slug = uniqueSlug(slug)
        p.append(slug)
        spans[p] = start..<end
    }

    // MARK: - Descend through remaining node types

    mutating func visitParagraph(_ paragraph: Paragraph) {
        if options.contains(.paragraphs), let range = paragraph.range {
            let start = byteOffset(of: range.lowerBound)
            let end = byteOffset(of: range.upperBound)
            var p = path
            let slug = uniqueSlug("para")
            p.append(slug)
            spans[p] = start..<end
        }
        descendInto(paragraph)
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        if options.contains(.blockQuotes), let range = blockQuote.range {
            let start = byteOffset(of: range.lowerBound)
            let end = byteOffset(of: range.upperBound)
            var p = path
            let slug = uniqueSlug("quote")
            p.append(slug)
            spans[p] = start..<end
        }
        descendInto(blockQuote)
    }

    mutating func visitOrderedList(_ orderedList: OrderedList) {
        descendInto(orderedList)
    }

    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        descendInto(unorderedList)
    }

    mutating func visitListItem(_ listItem: ListItem) {
        if options.contains(.listItems), let range = listItem.range {
            let start = byteOffset(of: range.lowerBound)
            let end = byteOffset(of: range.upperBound)
            var p = path
            let slug = uniqueSlug("li")
            p.append(slug)
            spans[p] = start..<end
        }
        descendInto(listItem)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        // leaf
    }

    mutating func visitHTMLBlock(_ html: HTMLBlock) {
        descendInto(html)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) { descendInto(emphasis) }
    mutating func visitStrong(_ strong: Strong) { descendInto(strong) }
    mutating func visitLink(_ link: Link) { descendInto(link) }
    mutating func visitImage(_ image: Image) { descendInto(image) }
    mutating func visitInlineCode(_ inlineCode: InlineCode) { descendInto(inlineCode) }
    mutating func visitInlineHTML(_ htmlInline: InlineHTML) { descendInto(htmlInline) }
    mutating func visitSoftBreak(_ softBreak: SoftBreak) {}
    mutating func visitLineBreak(_ lineBreak: LineBreak) {}
    mutating func visitText(_ text: Text) {}
    mutating func visitCustomInline(_ custom: CustomInline) { descendInto(custom) }
    mutating func visitCustomBlock(_ custom: CustomBlock) { descendInto(custom) }

    mutating func finalize(end: Int) {
        finalize(upTo: 0, end: end)
    }
}

public func buildIndex(document: Document, text: String, options: IndexOptions = .none) -> ASTIndex {
    var builder = IndexBuilder(text: text, options: options)
    builder.visit(document)
    var idx = ASTIndex()
    idx.map = builder.spans
    idx.headingRanges = builder.headingRanges
    return idx
}
