// MARK: - RuleRegistry
@MainActor
public final class RuleRegistry {
    public static let shared: RuleRegistry = RuleRegistry()
    private var rules: [LintRule] = [
        RequiredHeadingRule(),
        UniqueHeadingTitlesRule(),
        AllowedFencedTagsRule(),
        NoEmptySectionRule()
    ]

    private init() {}

    public func register(_ rule: LintRule) {
        rules.append(rule)
    }

    public var activeRules: [LintRule] { rules }
}
