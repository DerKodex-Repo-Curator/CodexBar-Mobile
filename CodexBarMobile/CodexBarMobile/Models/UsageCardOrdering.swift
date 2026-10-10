import CodexBarSync
import Foundation

// MARK: - Usage cards (iOS 2.5.0, Research/064)

/// One card in the Usage list: either a whole provider (all accounts behind
/// one card with detail tabs) or one account of an expanded provider.
struct UsageCard: Identifiable {
    /// Stable card key (`UsageCardKey`).
    let id: String
    /// Every account of the provider, used by the provider settings sheet.
    let providerGroup: ProviderAccountGroup
    /// Snapshot rendered on the card.
    let snapshot: ProviderUsageSnapshot
    /// Group opened by the detail view: the full provider group for a provider
    /// card, a single-account group for an account card.
    let detailGroup: ProviderAccountGroup
    /// 1-based account position for account cards, nil for provider cards.
    let accountOrdinal: Int?

    var providerID: String {
        self.providerGroup.providerID
    }

    var isAccountCard: Bool {
        self.accountOrdinal != nil
    }

    /// Account label used as the secondary sort name (never displayed).
    var accountSortLabel: String {
        guard let ordinal = self.accountOrdinal else { return "" }
        return self.providerGroup.tabLabel(forIndex: ordinal - 1)
    }
}

enum UsageCardBuilder {
    /// Source-ordered cards. Providers keep the Mac's first-appearance order;
    /// an expanded provider contributes its accounts in group order.
    static func cards(
        groups: [ProviderAccountGroup],
        preferences: UsageCardPreferences) -> [UsageCard]
    {
        var cards: [UsageCard] = []
        for group in groups {
            guard preferences.isExpanded(group.providerID) else {
                cards.append(UsageCard(
                    id: UsageCardKey.provider(group.providerID),
                    providerGroup: group,
                    snapshot: group.representative,
                    detailGroup: group,
                    accountOrdinal: nil))
                continue
            }
            let anchorIDs = preferences.anchorIDs(forAccounts: group.accounts)
            for (index, account) in group.accounts.enumerated() {
                cards.append(UsageCard(
                    id: UsageCardKey.account(anchorID: anchorIDs[index]),
                    providerGroup: group,
                    snapshot: account,
                    detailGroup: ProviderAccountGroup(
                        providerID: group.providerID,
                        providerName: account.providerName,
                        accounts: [account]),
                    accountOrdinal: index + 1))
            }
        }
        return cards
    }

    /// Card keys of a provider's accounts as they would render if expanded.
    static func accountKeys(
        for group: ProviderAccountGroup,
        preferences: UsageCardPreferences) -> [String]
    {
        preferences.anchorIDs(forAccounts: group.accounts).map { UsageCardKey.account(anchorID: $0) }
    }
}

// MARK: - Ordering

/// Sort inputs for one card, separated from SwiftUI so the ordering rules can
/// be tested as a pure function.
struct UsageCardSortDescriptor: Equatable, Sendable {
    let key: String
    let name: String
    let secondaryName: String
    let weeklyResetAt: Date?

    var orderingKey: WeeklyResetOrdering.Key {
        WeeklyResetOrdering.Key(resetAt: self.weeklyResetAt, name: self.name, secondaryName: self.secondaryName)
    }
}

struct UsageCardArrangement: Equatable, Sendable {
    let pinned: [String]
    let others: [String]

    var all: [String] {
        self.pinned + self.others
    }
}

enum UsageCardOrdering {
    /// Splits cards into the pinned and regular sections and orders each:
    /// by the chosen default rule, or by the stored manual order (cards the
    /// manual order has never seen follow in source order).
    static func arrange(
        _ descriptors: [UsageCardSortDescriptor],
        preferences: UsageCardPreferences) -> UsageCardArrangement
    {
        let sourceIndex = Dictionary(
            descriptors.enumerated().map { ($1.key, $0) },
            uniquingKeysWith: { first, _ in first })
        let sorted: [UsageCardSortDescriptor]
        if preferences.usesDefaultSort {
            sorted = descriptors.sorted { lhs, rhs in
                Self.precedes(lhs, rhs, rule: preferences.defaultSortRule, sourceIndex: sourceIndex)
            }
        } else {
            let manualIndex = Dictionary(
                preferences.manualOrder.enumerated().map { ($1, $0) },
                uniquingKeysWith: { first, _ in first })
            sorted = descriptors.sorted { lhs, rhs in
                let left = manualIndex[lhs.key] ?? Int.max
                let right = manualIndex[rhs.key] ?? Int.max
                if left != right { return left < right }
                return sourceIndex[lhs.key, default: 0] < sourceIndex[rhs.key, default: 0]
            }
        }
        let keys = sorted.map(\.key)
        return UsageCardArrangement(
            pinned: keys.filter { preferences.isPinned($0) },
            others: keys.filter { !preferences.isPinned($0) })
    }

    private static func precedes(
        _ lhs: UsageCardSortDescriptor,
        _ rhs: UsageCardSortDescriptor,
        rule: UsageDefaultSortRule,
        sourceIndex: [String: Int]) -> Bool
    {
        let result: Bool? = switch rule {
        case .alphabeticalAscending:
            WeeklyResetOrdering.compareNames(lhs.orderingKey, rhs.orderingKey, descending: false)
        case .alphabeticalDescending:
            WeeklyResetOrdering.compareNames(lhs.orderingKey, rhs.orderingKey, descending: true)
        case .weeklyReset:
            // Shared with the CodexBar widget's "By weekly reset" overview
            // (Research/073).
            WeeklyResetOrdering.precedes(lhs.orderingKey, rhs.orderingKey)
        }
        return result ?? (sourceIndex[lhs.key, default: 0] < sourceIndex[rhs.key, default: 0])
    }

    // MARK: Weekly reset

    /// Next weekly reset of a snapshot, or nil when it has no weekly window
    /// with a reset time (API-key providers, credit balances). The weekly
    /// rule, the account-level window preference and the roll-forward of
    /// past resets live in `WeeklyResetWindow` (Research/073), shared with
    /// the widget.
    static func weeklyResetDate(for snapshot: ProviderUsageSnapshot, now: Date) -> Date? {
        WeeklyResetWindow.nextReset(for: snapshot, now: now)
    }

    static func isWeekly(_ window: SyncRateWindow, observedAt: Date) -> Bool {
        WeeklyResetWindow.isWeekly(window, observedAt: observedAt)
    }

    static func descriptor(for card: UsageCard, now: Date) -> UsageCardSortDescriptor {
        UsageCardSortDescriptor(
            key: card.id,
            name: card.snapshot.providerName,
            secondaryName: card.accountSortLabel,
            weeklyResetAt: self.weeklyResetDate(for: card.snapshot, now: now))
    }

    /// Cards in display order, split into sections.
    static func arrangedCards(
        _ cards: [UsageCard],
        preferences: UsageCardPreferences,
        now: Date) -> (pinned: [UsageCard], others: [UsageCard])
    {
        let arrangement = self.arrange(
            cards.map { self.descriptor(for: $0, now: now) },
            preferences: preferences)
        let byKey = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return (
            arrangement.pinned.compactMap { byKey[$0] },
            arrangement.others.compactMap { byKey[$0] })
    }
}

// MARK: - Selection

/// Keeps the Usage detail selection valid when the card set changes
/// (expand/collapse, sync refresh, removed account, absorbed anchor).
enum UsageCardSelection {
    struct Resolution: Equatable {
        let key: String?
        let providerID: String?
        /// The selected provider is gone entirely; compact layouts should
        /// return to the list instead of showing an empty detail column.
        let providerGone: Bool
    }

    /// `arranged` is the display order; the first card of the same provider
    /// replaces a vanished selection.
    static func resolve(
        selectedKey: String?,
        selectedProviderID: String?,
        arranged: [UsageCard]) -> Resolution
    {
        guard let selectedKey else {
            return Resolution(key: nil, providerID: nil, providerGone: false)
        }
        if let card = arranged.first(where: { $0.id == selectedKey }) {
            return Resolution(key: card.id, providerID: card.providerID, providerGone: false)
        }
        if let selectedProviderID,
           let replacement = arranged.first(where: { $0.providerID == selectedProviderID })
        {
            return Resolution(key: replacement.id, providerID: selectedProviderID, providerGone: false)
        }
        return Resolution(key: nil, providerID: nil, providerGone: true)
    }
}
