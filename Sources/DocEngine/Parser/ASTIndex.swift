@_exported import MarkdownSupport
import Markdown

public typealias ASTIndex = MarkdownSupport.ASTIndex
public typealias IndexOptions = MarkdownSupport.IndexOptions

public func buildIndex(document: Document, text: String, options: IndexOptions = .none) -> ASTIndex {
    MarkdownSupport.buildIndex(document: document, text: text, options: options)
}
