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
        let c = try decoder.container(keyedBy: CodingKeys.self)
        severity = try c.decode(Severity.self, forKey: .severity)
        message = try c.decode(String.self, forKey: .message)
        let r = try c.decode(SourceRangeCodable.self, forKey: .range)
        range = r.range
        ruleID = try c.decode(String.self, forKey: .ruleID)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(severity, forKey: .severity)
        try c.encode(message, forKey: .message)
        try c.encode(SourceRangeCodable(range), forKey: .range)
        try c.encode(ruleID, forKey: .ruleID)
    }
}

struct SourceRangeCodable: Codable {
    var range: SourceRange
    init(_ r: SourceRange) { self.range = r }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let sl = try c.decode(Int.self, forKey: .startLine)
        let sc = try c.decode(Int.self, forKey: .startColumn)
        let el = try c.decode(Int.self, forKey: .endLine)
        let ec = try c.decode(Int.self, forKey: .endColumn)
        range = SourceRange(
            start: SourceLocation(line: sl, column: sc, source: nil),
            end: SourceLocation(line: el, column: ec, source: nil)
        )
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(range.lowerBound.line, forKey: .startLine)
        try c.encode(range.lowerBound.column, forKey: .startColumn)
        try c.encode(range.upperBound.line, forKey: .endLine)
        try c.encode(range.upperBound.column, forKey: .endColumn)
    }
    enum CodingKeys: String, CodingKey {
        case startLine, startColumn, endLine, endColumn
    }
}
