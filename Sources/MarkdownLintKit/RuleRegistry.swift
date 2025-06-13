// MARK: - RuleRegistry
@MainActor
public final class RuleRegistry {
    private var rules: [LintRule]

    public init(rules: [LintRule] = []) {
        self.rules = rules
    }

    public func register(_ rule: LintRule) {
        rules.append(rule)
    }

    public var activeRules: [LintRule] { rules }
}
