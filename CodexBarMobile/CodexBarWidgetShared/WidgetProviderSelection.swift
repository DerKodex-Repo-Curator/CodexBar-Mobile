import AppIntents
import Foundation
import WidgetKit

struct WidgetProviderEntity: AppEntity, Codable, Hashable, Sendable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Provider"
    static let defaultQuery = WidgetProviderQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.name)")
    }
}

struct WidgetProviderQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WidgetProviderEntity] {
        let catalogue = try await self.suggestedEntities()
        return identifiers.map { id in
            catalogue.first { $0.id == id } ?? WidgetProviderEntity(id: id, name: id)
        }
    }

    func suggestedEntities() async throws -> [WidgetProviderEntity] {
        let catalogue = try WidgetProviderCatalogue.read()
        #if targetEnvironment(simulator)
        if catalogue.isEmpty, ProcessInfo.processInfo.environment["CODEXBAR_WIDGET_DISABLE_SIMULATOR_MOCK"] != "1" {
            return CodexBarWidgetSnapshot.placeholder().topProviders.map {
                WidgetProviderEntity(id: $0.providerID, name: $0.providerName)
            }
        }
        #endif
        return catalogue.map { WidgetProviderEntity(id: $0.id, name: $0.name) }
    }
}

enum WidgetProviderResetText {
    static func days(_ resetsAt: Date?, now: Date) -> String? {
        guard let resetsAt else { return nil }
        let days = resetsAt.timeIntervalSince(now) / 86400
        guard days > 0 else { return String(localized: "Now") }
        if days < 0.1 { return String(localized: "<0.1d") }
        let number = days.formatted(.number.precision(.fractionLength(0...1)))
        return String(format: String(localized: "%@d"), number)
    }
}

extension WidgetProviderResetText {
    /// Hours until reset for windows shorter than a day (Research/071).
    static func hours(_ resetsAt: Date?, now: Date) -> String? {
        guard let resetsAt else { return nil }
        let hours = resetsAt.timeIntervalSince(now) / 3600
        guard hours > 0 else { return String(localized: "Now") }
        if hours < 0.1 { return String(localized: "<0.1h") }
        let number = hours.formatted(.number.precision(.fractionLength(0...1)))
        return String(format: String(localized: "%@h"), number)
    }
}

/// How the CodexBar widget's overview picks its providers (Research/073).
/// Configured by the overview's "Provider Selection" parameter in both widget
/// generations and kept outside `CodexBarWidgetConfigurationIntent`, whose
/// schema belongs to the legacy widget kind.
enum WidgetOverviewSelection: Equatable, Sendable {
    /// The provider slots, or automatic selection when none is set: the
    /// behavior of every widget placed before this option existed.
    case manual
    /// The `count` providers whose weekly reset comes soonest, whatever order
    /// the app's Usage cards use.
    case soonestWeeklyReset(count: Int)

    static let counts = 2...4
    /// Readable in every widget size, and the small widget's automatic count.
    static let defaultCount = 2

    /// `count` kept within `counts`.
    static func clampedCount(_ count: Int) -> Int {
        min(max(count, self.counts.lowerBound), self.counts.upperBound)
    }

    /// For the DEBUG timeline logs.
    var logDescription: String {
        switch self {
        case .manual: "manual"
        case let .soonestWeeklyReset(count): "soonestWeeklyReset(\(count))"
        }
    }
}

enum WidgetProviderSelection {
    /// The overview's providers for the configured selection.
    static func overview(
        from providers: [CodexBarWidgetProviderSummary],
        selected: [WidgetProviderEntity]?,
        selection: WidgetOverviewSelection,
        family: WidgetFamily,
        now: Date) -> [CodexBarWidgetProviderSummary]
    {
        switch selection {
        case .manual:
            self.resolve(from: providers, selected: selected, family: family, now: now)
        case let .soonestWeeklyReset(count):
            self.soonestWeeklyReset(from: providers, count: count, now: now)
        }
    }

    /// The app's "Weekly Reset (Soonest First)" order (`WeeklyResetOrdering`)
    /// over one entry per provider, cut to `count` (2 to 4). The entry kept
    /// for a provider is the one the overview shows in every mode (its first
    /// in `providers`), so its reset is the one that sorts it, like the app's
    /// collapsed provider card. Past resets roll forward by whole weeks;
    /// providers without a weekly reset follow by name; full ties keep the
    /// snapshot order. Only the synced summaries are read.
    static func soonestWeeklyReset(
        from providers: [CodexBarWidgetProviderSummary],
        count: Int,
        now: Date) -> [CodexBarWidgetProviderSummary]
    {
        var seen = Set<String>()
        let unique = providers.filter { seen.insert($0.providerID).inserted }
        let limit = WidgetOverviewSelection.clampedCount(count)
        let keyed = unique.enumerated().map { index, provider in
            (index: index, provider: provider, key: WeeklyResetOrdering.Key(
                resetAt: provider.weeklyResetsAt.map { WeeklyResetWindow.nextOccurrence(of: $0, after: now) },
                name: provider.providerName))
        }
        return keyed
            .sorted { lhs, rhs in WeeklyResetOrdering.precedes(lhs.key, rhs.key) ?? (lhs.index < rhs.index) }
            .prefix(limit)
            .map(\.provider)
    }

    /// The usage and reset an overview tile shows. "By weekly reset" shows
    /// the weekly window it sorts by, so the order reads soonest first; a
    /// provider without a weekly reset, and manual selection, keep the
    /// provider's most-used window as before.
    static func overviewFigures(
        for provider: CodexBarWidgetProviderSummary,
        selection: WidgetOverviewSelection,
        now: Date) -> (usagePercent: Double?, resetsAt: Date?)
    {
        guard case .soonestWeeklyReset = selection, let weeklyReset = provider.weeklyResetsAt else {
            return (provider.usagePercent, provider.resetsAt)
        }
        let next = WeeklyResetWindow.nextOccurrence(of: weeklyReset, after: now)
        // A reset that has passed since the data was built leaves its usage stale.
        return (next == weeklyReset ? provider.weeklyUsedPercent : nil, next)
    }

    static func resolve(
        from providers: [CodexBarWidgetProviderSummary],
        selected: [WidgetProviderEntity]?,
        family: WidgetFamily,
        now: Date) -> [CodexBarWidgetProviderSummary]
    {
        var seen = Set<String>()
        let unique = providers.filter { seen.insert($0.providerID).inserted }
        guard let selected, !selected.isEmpty else {
            return Array(unique.prefix(family == .systemSmall ? 2 : 4))
        }
        seen.removeAll()
        return selected.filter { seen.insert($0.id).inserted }.prefix(4).map { entity in
            unique.first { $0.providerID == entity.id } ?? CodexBarWidgetProviderSummary(
                id: "unavailable|\(entity.id)",
                providerName: entity.name,
                providerID: entity.id,
                loginMethod: nil,
                usagePercent: nil,
                todayCostUSD: nil,
                thirtyDayCostUSD: nil,
                tokensToday: nil,
                isError: true,
                statusMessage: String(localized: "Unavailable"),
                lastUpdated: now)
        }
    }

    /// Providers for the Quota Pace widget. A configured provider is always
    /// honored: without data for its window it comes back without
    /// `quotaPace` (the view says so) instead of silently showing another
    /// provider. Automatic selection prefers providers with a pace, then a
    /// chart (Codex, Claude), then the least remaining quota.
    ///
    /// `windowChoice` (Research/071) points a configured provider at one of
    /// its windows; without a choice, or with a choice for another provider
    /// or a window that is gone, a configured provider follows its default
    /// (weekly) window. Automatic provider selection ignores the choice and
    /// keeps the Research/065 data and ranking.
    static func pace(
        from providers: [CodexBarWidgetProviderSummary],
        selected: [WidgetProviderEntity]?,
        limit: Int,
        windowChoice: String? = nil,
        now: Date = .now) -> [CodexBarWidgetProviderSummary]
    {
        if let selected, !selected.isEmpty {
            var seen = Set<String>()
            return selected.filter { seen.insert($0.id).inserted }.prefix(limit).map { entity in
                let windowID = QuotaPaceWindowChoice.windowID(from: windowChoice, providerID: entity.id)
                let accounts = providers.filter { !$0.isError && $0.providerID == entity.id }
                // With several accounts, a chosen window comes only from the
                // accounts that report it; without one, every account falls
                // back to its default window.
                let holders = windowID.map { id in
                    accounts.filter { $0.quotaPace?.windows.contains { $0.id == id } == true }
                } ?? []
                return (holders.isEmpty ? accounts : holders)
                    .compactMap { provider -> CodexBarWidgetProviderSummary? in
                        guard let pace = provider.quotaPace?.configured(windowID: windowID),
                              pace.hasDisplayableData
                        else { return nil }
                        return provider.withQuotaPace(pace)
                    }
                    .max { Self.paceRank($0) < Self.paceRank($1) }
                    ?? CodexBarWidgetProviderSummary(
                        id: "unavailable|\(entity.id)",
                        providerName: entity.name,
                        providerID: entity.id,
                        loginMethod: nil,
                        usagePercent: nil,
                        todayCostUSD: nil,
                        thirtyDayCostUSD: nil,
                        tokensToday: nil,
                        isError: false,
                        statusMessage: nil,
                        lastUpdated: now)
            }
        }
        let candidates = providers.filter { !$0.isError && $0.quotaPace?.isAutomaticCandidate == true }
        var seen = Set<String>()
        return candidates
            .sorted { lhs, rhs in
                let lhsRank = Self.paceRank(lhs)
                let rhsRank = Self.paceRank(rhs)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
                let lhsRemaining = lhs.quotaPace?.paceRemainingPercent ?? 100
                let rhsRemaining = rhs.quotaPace?.paceRemainingPercent ?? 100
                if lhsRemaining != rhsRemaining { return lhsRemaining < rhsRemaining }
                return lhs.providerName.localizedCaseInsensitiveCompare(rhs.providerName) == .orderedAscending
            }
            .filter { seen.insert($0.providerID).inserted }
            .prefix(limit)
            .map(\.self)
    }

    /// Pace outranks a chart; providers with both rank highest. A followed
    /// window only counts its own chart.
    private static func paceRank(_ provider: CodexBarWidgetProviderSummary) -> Int {
        let hasPace = provider.quotaPace?.pace != nil
        let hasChart = provider.quotaPace?.hasChart == true
        return (hasPace ? 2 : 0) + (hasChart ? 1 : 0)
    }

    static func columns(count: Int, family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: count >= 3 ? 2 : 1
        case .systemMedium: count == 4 ? 2 : max(1, count)
        case .systemLarge: count > 2 ? 2 : 1
        case .systemExtraLarge: max(1, count)
        default: max(1, min(count, 2))
        }
    }
}
