import CodexBarSync
import Foundation

/// Which quota windows are weekly and when the next weekly reset comes
/// (Research/073). Shared by the app's "Weekly Reset (Soonest First)" card
/// order, the Quota pace default window and the CodexBar widget's "By weekly
/// reset" overview, so they always agree.
enum WeeklyResetWindow {
    static let weekMinutes = 7 * 24 * 60
    static let week: TimeInterval = 7 * 24 * 60 * 60

    /// Longest time from the observation to the reset that the label
    /// fallback accepts: a week plus the half day the length rule allows.
    static let labelFallbackReach: TimeInterval = 7.5 * 24 * 60 * 60

    /// Whether a window is the provider's weekly window:
    ///
    /// 1. A declared `period` decides: only `.weekly` is weekly.
    /// 2. Without one, a length that rounds to seven whole days (6.5 to just
    ///    under 7.5 days). Grok's length is its billing period's end minus
    ///    start, floored to minutes (`GrokCreditsProxyFetcher.windowMinutes`),
    ///    so it is often 10079 rather than 10080; rounding to whole days is
    ///    the Mac's own rule for naming a Grok window (`GrokProviderDescriptor
    ///    .primaryLabel`). 5-hour, daily and 30-day windows stay far outside.
    /// 3. Without a length either, the Mac's "Weekly" label, and only with a
    ///    reset at most 7.5 days after `observedAt` (when the data was
    ///    captured). Grok's untyped credits window arrives as "Weekly"
    ///    (`GrokProviderDescriptor.displayLabel`), but the Mac also falls
    ///    back to "Weekly" for a monthly pool whose reset is under 3.5 or
    ///    12.5–19.5 days away, and labels a reset-less fallback window
    ///    (Windsurf flow actions) "Weekly"; the reach and the reset rule
    ///    those out. Mac labels are unlocalized English constants.
    static func isWeekly(_ window: SyncRateWindow, observedAt: Date) -> Bool {
        self.isWeekly(
            period: window.period,
            windowMinutes: window.windowMinutes,
            label: window.label,
            resetsAt: window.resetsAt,
            observedAt: observedAt)
    }

    static func isWeekly(
        period: SyncRateWindowPeriod?,
        windowMinutes: Int?,
        label: String?,
        resetsAt: Date?,
        observedAt: Date) -> Bool
    {
        if let period { return period == .weekly }
        if let windowMinutes { return self.isWeekLength(minutes: windowMinutes) }
        guard let label = label?.trimmingCharacters(in: .whitespacesAndNewlines),
              label.caseInsensitiveCompare("Weekly") == .orderedSame,
              let resetsAt
        else { return false }
        return resetsAt.timeIntervalSince(observedAt) <= self.labelFallbackReach
    }

    /// Whether a declared period or length (no label) says weekly, for
    /// unlabeled windows such as the widget's window names.
    static func isWeekly(period: SyncRateWindowPeriod?, windowMinutes: Int?) -> Bool {
        if let period { return period == .weekly }
        return windowMinutes.map(self.isWeekLength) ?? false
    }

    private static func isWeekLength(minutes: Int) -> Bool {
        Int((Double(minutes) / 1440).rounded(.toNearestOrAwayFromZero)) == 7
    }

    /// The provider's next weekly reset, or nil without a weekly window that
    /// has a reset time. A reset already in the past rolls forward by whole
    /// weeks, so data that has not refreshed since its reset still sorts by
    /// its next one.
    static func nextReset(for provider: ProviderUsageSnapshot, now: Date) -> Date? {
        self.soonest(for: provider, now: now)?.nextReset
    }

    /// The weekly window whose next reset comes first, with that reset. When
    /// the provider has account-level weekly windows, only they count:
    /// Claude's Sonnet/Opus slot, `claude-weekly-scoped-*` and
    /// `claude-routines` limits are carve-outs that never stand for the
    /// account (`QuotaPaceWindowSelection.isAccountWeeklyCandidate`, the Mac's
    /// weekly switcher rule). Without one, every weekly window counts. The
    /// pool is chosen before reset-less windows drop out, so an account
    /// window without a reset time never hands the account's place to a
    /// carve-out. The app's card order, the widget order and the widget tile
    /// all use this.
    static func soonest(
        for provider: ProviderUsageSnapshot,
        now: Date) -> (window: SyncRateWindow, nextReset: Date)?
    {
        let weekly = QuotaPaceWindowSelection.candidates(for: provider).filter { candidate in
            self.isWeekly(candidate.window, observedAt: provider.lastUpdated)
        }
        let account = weekly.filter {
            QuotaPaceWindowSelection.isAccountWeeklyCandidate($0, providerID: provider.providerID)
        }
        return (account.isEmpty ? weekly : account)
            .compactMap { candidate in
                candidate.window.resetsAt.map {
                    (window: candidate.window, nextReset: self.nextOccurrence(of: $0, after: now))
                }
            }
            // Windows that reset together (Antigravity's per-model weeklies) hand the
            // tile to the fuller one with known usage, as the Mac's most-constrained
            // rule picks the fuller window.
            .min {
                if $0.nextReset != $1.nextReset { return $0.nextReset < $1.nextReset }
                let leftKnown = $0.window.usageKnown && $0.window.usedPercent.isFinite
                let rightKnown = $1.window.usageKnown && $1.window.usedPercent.isFinite
                if leftKnown != rightKnown { return leftKnown }
                return $0.window.usedPercent > $1.window.usedPercent
            }
    }

    /// Used percent of the fullest weekly window from the same pool as `soonest`
    /// when none of them reports a reset time (Research/076): the overview tile
    /// still shows weekly usage, just without a countdown. Nil when the pool is
    /// empty or no window has known, finite usage.
    static func resetlessUsedPercent(for provider: ProviderUsageSnapshot) -> Double? {
        let weekly = QuotaPaceWindowSelection.candidates(for: provider).filter { candidate in
            self.isWeekly(candidate.window, observedAt: provider.lastUpdated)
        }
        let account = weekly.filter {
            QuotaPaceWindowSelection.isAccountWeeklyCandidate($0, providerID: provider.providerID)
        }
        let pool = account.isEmpty ? weekly : account
        guard pool.allSatisfy({ $0.window.resetsAt == nil }) else { return nil }
        return pool.map(\.window)
            .filter { $0.usageKnown && $0.usedPercent.isFinite }
            .map { min(100, max(0, $0.usedPercent)) }
            .max()
    }

    /// Used percent of that window while its observation is current: known
    /// usage whose reset is still ahead (after a missed reset it is stale).
    static func currentUsedPercent(of window: SyncRateWindow, now: Date) -> Double? {
        guard window.usageKnown, window.usedPercent.isFinite,
              let reset = window.resetsAt, reset > now
        else { return nil }
        return min(100, max(0, window.usedPercent))
    }

    static func nextOccurrence(of reset: Date, after now: Date) -> Date {
        guard reset <= now else { return reset }
        let elapsedWeeks = floor(now.timeIntervalSince(reset) / self.week) + 1
        return reset.addingTimeInterval(elapsedWeeks * self.week)
    }
}

/// The "Weekly Reset (Soonest First)" comparison shared by the app's cards
/// and the widget overview (Research/064, 073): the soonest weekly reset
/// first; items without one after them; ties and items without a reset by
/// name, then by a secondary name (an account label). Nil means a full tie,
/// which callers break by their source order.
enum WeeklyResetOrdering {
    struct Key: Equatable, Sendable {
        let resetAt: Date?
        let name: String
        let secondaryName: String

        init(resetAt: Date?, name: String, secondaryName: String = "") {
            self.resetAt = resetAt
            self.name = name
            self.secondaryName = secondaryName
        }
    }

    static func precedes(_ lhs: Key, _ rhs: Key) -> Bool? {
        switch (lhs.resetAt, rhs.resetAt) {
        case let (left?, right?) where left != right:
            left < right
        case (.some, nil):
            true
        case (nil, .some):
            false
        default:
            self.compareNames(lhs, rhs, descending: false)
        }
    }

    /// Name first, then the secondary name (always ascending so the accounts
    /// of one provider stay readable in both directions).
    static func compareNames(_ lhs: Key, _ rhs: Key, descending: Bool) -> Bool? {
        let primary = self.compare(lhs.name, rhs.name)
        if primary != .orderedSame {
            return descending ? primary == .orderedDescending : primary == .orderedAscending
        }
        let secondary = self.compare(lhs.secondaryName, rhs.secondaryName)
        if secondary != .orderedSame {
            return secondary == .orderedAscending
        }
        return nil
    }

    private static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: [.caseInsensitive, .numeric, .diacriticInsensitive, .widthInsensitive])
    }
}
