import Markdown

// MARK: - Diagnostic
public struct Diagnostic: Codable, Hashable {
    public enum Severity: String, Codable { case info, warning, error }
    public let severity: Severity
    public let message: String
    public let range: SourceRange
    public let ruleID: String

    enum CodingKeys: String, CodingKey { case severity, message, range, ruleID }

    public init(severity: Severity, message: String, range: SourceRange, ruleID: String) {
        self.severity = severity
        self.message = message
        self.range = range
        self.ruleID = ruleID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        severity = try container.decode(Severity.self, forKey: .severity)
        message = try container.decode(String.self, forKey: .message)
        let decodedRange = try container.decode(SourceRangeCodable.self, forKey: .range)
        range = decodedRange.range
        ruleID = try container.decode(String.self, forKey: .ruleID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(severity, forKey: .severity)
        try container.encode(message, forKey: .message)
        try container.encode(SourceRangeCodable(range), forKey: .range)
        try container.encode(ruleID, forKey: .ruleID)
    }
}

struct SourceRangeCodable: Codable {
    var range: SourceRange
    init(_ range: SourceRange) { self.range = range }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let startLine = try container.decode(Int.self, forKey: .startLine)
        let startColumn = try container.decode(Int.self, forKey: .startColumn)
        let endLine = try container.decode(Int.self, forKey: .endLine)
        let endColumn = try container.decode(Int.self, forKey: .endColumn)
        range = SourceRange(
            start: SourceLocation(line: startLine, column: startColumn, source: nil),
            end: SourceLocation(line: endLine, column: endColumn, source: nil)
        )
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(range.lowerBound.line, forKey: .startLine)
        try container.encode(range.lowerBound.column, forKey: .startColumn)
        try container.encode(range.upperBound.line, forKey: .endLine)
        try container.encode(range.upperBound.column, forKey: .endColumn)
    }
    enum CodingKeys: String, CodingKey {
        case startLine, startColumn, endLine, endColumn
    }
}
