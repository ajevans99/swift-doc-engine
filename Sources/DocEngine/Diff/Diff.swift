import Foundation

/// Extremely small diff generator that produces a unified style patch by
/// comparing line sequences. It exists so the package has no dependency on
/// external tools. The algorithm leverages `Collection.difference(from:)`
/// which implements Myers diff. The output format is intentionally minimal
/// and suited for unit testing rather than code review.
public struct SimpleDiff {
    /// Create a unified diff of two strings.
    /// - Parameters:
    ///   - old: The original text to be replaced.
    ///   - new: The updated text to compare against `old`.
    /// - Returns: A unified diff beginning with `--- old` and `+++ new` lines.
    /// - Note: Only line level additions and removals are emitted. Context
    ///   lines are omitted for simplicity.
    public static func unified(old: String, new: String) -> String {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false)
        var result = ""
        result += "--- old\n"
        result += "+++ new\n"
        for diff in newLines.difference(from: oldLines) {
            switch diff {
            case let .remove(_, element, _):
                result += "-" + element + "\n"
            case let .insert(_, element, _):
                result += "+" + element + "\n"
            }
        }
        return result
    }
}

