// MARK: - RuleRegistry
@MainActor
public final class RuleRegistry {
    public static let shared: RuleRegistry = RuleRegistry()
    private var rules: [LintRule] = []

    private init() {}

    public func register(_ rule: LintRule) {
        rules.append(rule)
    }

    public func registerBuiltInRules() {
        rules += [
            RequiredHeadingRule(),
            UniqueHeadingTitlesRule(),
            AllowedFencedTagsRule(),
            NoEmptySectionRule()
        ]
    }

    public func reset() {
        rules.removeAll()
    }

    public var activeRules: [LintRule] { rules }
}
